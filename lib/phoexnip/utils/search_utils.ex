defmodule Phoexnip.SearchUtils do
  @moduledoc """
  TBA
  """
  import Ecto.Query, warn: false

  alias Phoexnip.Repo
  alias Phoexnip.ImportUtils

  @sensitive_fields [:hashed_password, :password, :current_password, :password_confirmation]

  @exact_types [:integer, :float, :decimal, :date, :utc_datetime, :boolean, :id]

  @list_keywords ~w(range not_range after after_equal before before_equal and or exact exact_and exact_or exact_not not not_empty empty)

  @temporal_keywords ~w(after after_equal before before_equal)

  @doc """
  TBA
  """
  @spec search(
          opts :: [
            module: module(),
            args: %{optional(atom()) => any()},
            pagination: %{optional(:page) => pos_integer(), optional(:per_page) => pos_integer()},
            use_or: boolean(),
            drop_args: [atom()],
            order_by: atom() | [atom()] | [{atom(), :asc | :desc}],
            user_timezone: String.t(),
            preload: boolean() | [atom()],
            order_method: :asc | :desc
          ]
        ) :: %{
          entries: [struct()],
          page_number: pos_integer(),
          page_size: non_neg_integer(),
          total_entries: non_neg_integer(),
          total_pages: pos_integer()
        }
  def search(opts) do
    # Extract options
    module = Keyword.fetch!(opts, :module)
    args = Keyword.get(opts, :args, %{})
    pagination = Keyword.get(opts, :pagination, %{})
    use_or = Keyword.get(opts, :use_or, false)
    drop_args = Keyword.get(opts, :drop_args, [])
    order_by = Keyword.get(opts, :order_by, :id)
    user_timezone = Keyword.get(opts, :user_timezone, "Etc/UTC")
    preload = Keyword.get(opts, :preload, [])
    order_method = Keyword.get(opts, :order_method, :asc)
    distinct = Keyword.get(opts, :distinct, false)

    ctx = %{module: module, user_timezone: user_timezone, use_or: use_or}
    normalized_order_by = normalize_order_by(order_by, order_method)

    # Clean and parse arguments, then extract special filter keys
    cleaned_args = clean_and_parse_args(args, drop_args)
    {or_filters, remaining} = Map.pop(cleaned_args, :_or)
    {multi_or_filters, remaining} = Map.pop(remaining, :_multi_or)

    # Build query pipeline
    base_query = from(p in module, as: :p)

    {query, joined} = apply_filters(remaining, base_query, ctx)
    {query, joined} = apply_or_filters(or_filters, query, joined, ctx)
    {query, joined} = apply_multi_or_filters(multi_or_filters, query, joined, ctx)
    {final_query, count_query} = prepare_final_query(query, joined, normalized_order_by, distinct)

    execute_query(final_query, count_query, pagination, preload, module, distinct)
  end

  defp clean_and_parse_args(args, drop_args) do
    args
    |> Map.drop(@sensitive_fields ++ drop_args)
    |> parse_association_keys()
  end

  defp parse_association_keys(args) do
    Enum.into(args, %{}, fn {key, value} ->
      key_str = to_string(key)

      if String.contains?(key_str, "@") do
        [field, assoc] = String.split(key_str, "@", parts: 2)
        {{String.to_existing_atom(field), String.to_existing_atom(assoc)}, value}
      else
        {key, value}
      end
    end)
  end

  defp normalize_order_by(order_by, default_method) do
    case order_by do
      field when is_atom(field) ->
        [{field, default_method}]

      {field, method} when is_atom(field) and method in [:asc, :desc] ->
        [{field, method}]

      fields when is_list(fields) ->
        Enum.map(fields, fn
          field when is_atom(field) -> {field, default_method}
          {field, method} when is_atom(field) and method in [:asc, :desc] -> {field, method}
          _ -> {:id, default_method}
        end)

      _ ->
        [{:id, default_method}]
    end
  end

  defp apply_filters(filters, query, ctx) do
    Enum.reduce(filters, {query, MapSet.new()}, fn filter, {acc_query, joined} ->
      apply_single_filter(filter, acc_query, joined, ctx)
    end)
  end

  defp apply_single_filter({{field, assoc}, value}, query, joined, ctx) when not is_nil(assoc) do
    if non_value?(value) do
      {query, joined}
    else
      query = ensure_association_joined(query, assoc, joined)
      assoc_module = get_assoc_module(ctx.module, assoc)
      new_query = build_field_query(query, assoc_module, assoc, field, value, ctx)
      {new_query, MapSet.put(joined, assoc)}
    end
  end

  defp apply_single_filter({field, value}, query, joined, ctx) do
    if non_value?(value) do
      {query, joined}
    else
      new_query = build_field_query(query, ctx.module, :p, field, value, ctx)
      {new_query, joined}
    end
  end

  defp apply_or_filters(nil, query, joined, _ctx), do: {query, joined}

  defp apply_or_filters(or_filters, query, joined, ctx) do
    parsed = or_filters |> parse_association_keys() |> drop_blank_filters()

    if map_size(parsed) == 0 do
      {query, joined}
    else
      {query, joined} = ensure_filter_associations_joined(query, parsed, joined)
      or_dynamic = build_or_dynamic(parsed, ctx)
      {from(r in query, where: ^or_dynamic), joined}
    end
  end

  defp apply_multi_or_filters(nil, query, joined, _ctx), do: {query, joined}

  defp apply_multi_or_filters(multi_or_filters, query, joined, ctx) do
    parsed_groups =
      multi_or_filters
      |> Enum.map(&(&1 |> parse_association_keys() |> drop_blank_filters()))
      |> Enum.reject(&(map_size(&1) == 0))

    if parsed_groups == [] do
      {query, joined}
    else
      {query, joined} =
        Enum.reduce(parsed_groups, {query, joined}, fn group, {q, j} ->
          ensure_filter_associations_joined(q, group, j)
        end)

      or_dynamic = build_multi_or_dynamic(parsed_groups, ctx)
      {from(r in query, where: ^or_dynamic), joined}
    end
  end

  defp ensure_association_joined(query, assoc, joined) do
    if MapSet.member?(joined, assoc) do
      query
    else
      from(q in query, join: a in assoc(q, ^assoc), as: ^assoc)
    end
  end

  defp ensure_filter_associations_joined(query, filters, joined) do
    needed_assocs = extract_associations_from_filters(filters)

    Enum.reduce(MapSet.to_list(needed_assocs), {query, joined}, fn assoc, {q, j} ->
      if MapSet.member?(j, assoc) do
        {q, j}
      else
        {from(sq in q, join: a in assoc(sq, ^assoc), as: ^assoc), MapSet.put(j, assoc)}
      end
    end)
  end

  defp extract_associations_from_filters(filters) do
    Enum.reduce(filters, MapSet.new(), fn
      {{_field, assoc}, value}, acc -> if non_value?(value), do: acc, else: MapSet.put(acc, assoc)
      {_field, _value}, acc -> acc
    end)
  end

  defp get_assoc_module(module, assoc) do
    case module.__schema__(:association, assoc) do
      nil -> raise "Association :#{assoc} not found on module #{module}"
      association -> association.related
    end
  end

  defp build_or_dynamic(filters, ctx) do
    Enum.reduce(filters, dynamic(false), fn filter, acc ->
      case filter do
        {{field, assoc}, value} ->
          if non_value?(value) do
            acc
          else
            assoc_module = get_assoc_module(ctx.module, assoc)
            comp = build_field_condition(assoc_module, assoc, field, value, ctx.user_timezone)
            dynamic([p], ^acc or ^comp)
          end

        {field, value} ->
          if non_value?(value) do
            acc
          else
            comp = build_field_condition(ctx.module, :p, field, value, ctx.user_timezone)
            dynamic([p], ^acc or ^comp)
          end
      end
    end)
  end

  defp build_multi_or_dynamic(groups, ctx) do
    Enum.reduce(groups, dynamic(false), fn group, or_acc ->
      group_dynamic = build_group_and_dynamic(group, ctx)
      dynamic([p], ^or_acc or ^group_dynamic)
    end)
  end

  defp build_group_and_dynamic(group, ctx) do
    Enum.reduce(group, dynamic(true), fn filter, and_acc ->
      case filter do
        {{field, assoc}, value} ->
          if non_value?(value) do
            and_acc
          else
            assoc_module = get_assoc_module(ctx.module, assoc)
            comp = build_field_condition(assoc_module, assoc, field, value, ctx.user_timezone)
            dynamic([p], ^and_acc and ^comp)
          end

        {field, value} ->
          if non_value?(value) do
            and_acc
          else
            comp = build_field_condition(ctx.module, :p, field, value, ctx.user_timezone)
            dynamic([p], ^and_acc and ^comp)
          end
      end
    end)
  end

  defp build_field_condition(module, binding, field, value, user_timezone) do
    cond do
      array_type_field?(module, field) ->
        arr_value = List.wrap(value)
        dynamic([{^binding, a}], fragment("? && ?", field(a, ^field), ^arr_value))

      exact_type_field?(module, field) ->
        dynamic(
          [{^binding, a}],
          field(a, ^field) == ^convert_value_to_field(module, field, value, user_timezone)
        )

      true ->
        dynamic(
          [{^binding, a}],
          fragment("? ILIKE ?", field(a, ^field), ^"%#{value}%")
        )
    end
  end

  defp prepare_final_query(query, joined, order_by_list, distinct) do
    # Ensure associations needed for ordering are joined
    {query, _joined} =
      Enum.reduce(order_by_list, {query, joined}, fn {order_by, _method},
                                                     {acc_query, acc_joined} ->
        order_str = to_string(order_by)

        if String.contains?(order_str, "@") do
          [_field, assoc_str] = String.split(order_str, "@", parts: 2)
          assoc = String.to_existing_atom(assoc_str)
          query = ensure_association_joined(acc_query, assoc, acc_joined)
          {query, MapSet.put(acc_joined, assoc)}
        else
          {acc_query, acc_joined}
        end
      end)

    # Build order clauses
    order_clauses =
      Enum.map(order_by_list, fn {order_by, method} ->
        order_str = to_string(order_by)

        if String.contains?(order_str, "@") do
          [field_str, assoc_str] = String.split(order_str, "@", parts: 2)
          field = String.to_existing_atom(field_str)
          assoc = String.to_existing_atom(assoc_str)
          {method, dynamic([{^assoc, a}], field(a, ^field))}
        else
          {method, dynamic([p], field(p, ^order_by))}
        end
      end)

    final_query = from(q in query, order_by: ^order_clauses)
    final_query = if distinct, do: from(q in final_query, distinct: true), else: final_query
    {final_query, query}
  end

  defp execute_query(final_query, count_query, pagination, preload, module, distinct) do
    count_select =
      if distinct do
        dynamic([p], count(field(as(:p), :id), :distinct))
      else
        dynamic([p], count(field(as(:p), :id)))
      end

    case pagination do
      %{page: page, per_page: per_page} ->
        total = Repo.one(from(q in count_query, select: ^count_select))

        entries =
          final_query
          |> offset(^((page - 1) * per_page))
          |> limit(^per_page)
          |> Repo.all()
          |> apply_preload(preload, module)

        %{
          entries: entries,
          page_number: page,
          page_size: per_page,
          total_entries: total,
          total_pages: max(ceil(total / per_page), 1)
        }

      _ ->
        entries = final_query |> Repo.all() |> apply_preload(preload, module)
        total = Repo.one(from(q in count_query, select: ^count_select))

        %{
          entries: entries,
          page_number: 1,
          page_size: length(entries),
          total_entries: total,
          total_pages: 1
        }
    end
  end

  defp apply_preload(results, preload, module) do
    cond do
      preload === true -> Repo.preload(results, ImportUtils.preload_all(module))
      is_list(preload) and preload != [] -> Repo.preload(results, preload)
      true -> results
    end
  end

  defp build_field_query(query, module, binding, field, value, ctx) do
    cond do
      field in [:_fields_diff, :_fields_sum] and is_list(value) ->
        handle_fields_operation(query, module, binding, field, value, ctx)

      non_value?(value) ->
        query

      is_list(value) ->
        handle_list_value(query, module, binding, field, value, ctx)

      true ->
        handle_single_value(query, module, binding, field, value, ctx)
    end
  end

  defp handle_single_value(query, module, binding, field, value, ctx) do
    condition =
      cond do
        array_type_field?(module, field) ->
          arr_value = List.wrap(value)

          if ctx.use_or do
            dynamic([{^binding, r}], fragment("? && ?", field(r, ^field), ^arr_value))
          else
            dynamic([{^binding, r}], fragment("? @> ?", field(r, ^field), ^arr_value))
          end

        exact_type_field?(module, field) ->
          dynamic(
            [{^binding, r}],
            field(r, ^field) == ^convert_value_to_field(module, field, value, ctx.user_timezone)
          )

        true ->
          dynamic([{^binding, r}], fragment("? ILIKE ?", field(r, ^field), ^"%#{value}%"))
      end

    if ctx.use_or do
      from(r in query, or_where: ^condition)
    else
      from(r in query, where: ^condition)
    end
  end

  defp handle_list_value(query, module, binding, field, value, ctx) do
    if array_type_field?(module, field) do
      handle_array_field_value(query, module, binding, field, value, ctx)
    else
      filtered = Enum.reject(value, &non_value?/1)

      if filtered == [],
        do: query,
        else: do_handle_list_value(query, module, binding, field, value, ctx)
    end
  end

  defp handle_array_field_value(query, _module, binding, field, value, ctx) do
    {keyword, values} = extract_list_keyword(value)
    arr_values = Enum.reject(values, &non_value?/1)

    if arr_values == [] do
      query
    else
      condition =
        if keyword == "or" or ctx.use_or do
          dynamic([{^binding, r}], fragment("? && ?", field(r, ^field), ^arr_values))
        else
          dynamic([{^binding, r}], fragment("? @> ?", field(r, ^field), ^arr_values))
        end

      from(r in query, where: ^condition)
    end
  end

  defp do_handle_list_value(query, module, binding, field, value, ctx) do
    {keyword, values} = extract_list_keyword(value)

    if values == [] and keyword not in ["not_empty", "empty"] do
      query
    else
      apply_list_keyword(query, module, binding, field, keyword, values, ctx)
    end
  end

  defp extract_list_keyword(value) do
    last = List.last(value)

    if is_binary(last) and last in @list_keywords do
      {last, Enum.drop(value, -1)}
    else
      {nil, value}
    end
  end

  defp apply_list_keyword(query, module, binding, field, keyword, values, ctx) do
    case keyword do
      # Range operations
      "range" ->
        apply_range(query, module, binding, field, values, ctx, false)

      "not_range" ->
        apply_range(query, module, binding, field, values, ctx, true)

      # Temporal operations
      k when k in @temporal_keywords ->
        apply_temporal(query, module, binding, field, k, values, ctx)

      # Empty checks
      "not_empty" ->
        from(r in query,
          where: fragment("? IS NOT NULL OR ? != ''", field(r, ^field), field(r, ^field))
        )

      "empty" ->
        from(r in query,
          where: fragment("? IS NULL OR ? = ''", field(r, ^field), field(r, ^field))
        )

      # Match operations - dispatch to unified handler
      _ ->
        condition =
          build_match_condition(binding, module, field, keyword, values, ctx.user_timezone)

        from(r in query, where: ^condition)
    end
  end

  defp build_match_condition(binding, module, field, keyword, values, user_timezone) do
    is_exact = exact_type_field?(module, field)

    case keyword do
      "exact" ->
        build_exact_single(binding, module, field, values, user_timezone)

      "exact_or" ->
        build_multi_match(binding, module, field, values, user_timezone, :or, :exact)

      "exact_and" ->
        build_multi_match(binding, module, field, values, user_timezone, :and, :exact)

      "exact_not" ->
        build_not_match(binding, module, field, values, user_timezone, :exact)

      "or" ->
        build_multi_match(
          binding,
          module,
          field,
          values,
          user_timezone,
          :or,
          if(is_exact, do: :exact, else: :ilike)
        )

      "and" ->
        build_multi_match(
          binding,
          module,
          field,
          values,
          user_timezone,
          :and,
          if(is_exact, do: :exact, else: :ilike)
        )

      "not" ->
        build_not_match(
          binding,
          module,
          field,
          values,
          user_timezone,
          if(is_exact, do: :exact, else: :ilike)
        )

      _ ->
        build_multi_match(
          binding,
          module,
          field,
          values,
          user_timezone,
          :and,
          if(is_exact, do: :exact, else: :ilike)
        )
    end
  end

  defp build_exact_single(binding, module, field, values, user_timezone) do
    case values do
      [nil] ->
        dynamic([{^binding, r}], is_nil(field(r, ^field)))

      [v] ->
        converted = convert_value_to_field(module, field, v, user_timezone)
        dynamic([{^binding, r}], field(r, ^field) == ^converted)

      _ ->
        dynamic(true)
    end
  end

  defp build_multi_match(binding, module, field, values, user_timezone, combinator, match_type) do
    base = if combinator == :or, do: dynamic(false), else: dynamic(true)

    Enum.reduce(values, base, fn v, acc ->
      cond do
        is_nil(v) ->
          acc

        match_type == :exact ->
          converted = convert_value_to_field(module, field, v, user_timezone)
          condition = dynamic([{^binding, r}], field(r, ^field) == ^converted)
          combine_dynamic(acc, condition, combinator, binding)

        true ->
          pattern = "%#{v}%"
          condition = dynamic([{^binding, r}], fragment("? ILIKE ?", field(r, ^field), ^pattern))
          combine_dynamic(acc, condition, combinator, binding)
      end
    end)
  end

  defp build_not_match(binding, module, field, values, user_timezone, match_type) do
    if match_type == :exact do
      build_exact_not(binding, module, field, values, user_timezone)
    else
      build_ilike_not(binding, module, field, values)
    end
  end

  defp build_exact_not(binding, module, field, values, user_timezone) do
    converted = Enum.map(values, &convert_value_to_field(module, field, &1, user_timezone))
    has_nil? = Enum.any?(converted, &is_nil/1)
    non_nils = converted |> Enum.reject(&is_nil/1) |> Enum.uniq()

    cond do
      has_nil? and non_nils == [] ->
        dynamic([{^binding, r}], not is_nil(field(r, ^field)))

      has_nil? ->
        dynamic(
          [{^binding, r}],
          not is_nil(field(r, ^field)) and field(r, ^field) not in ^non_nils
        )

      non_nils != [] ->
        dynamic([{^binding, r}], field(r, ^field) not in ^non_nils)

      true ->
        dynamic(true)
    end
  end

  defp build_ilike_not(binding, _module, field, values) do
    {dyn, has_nil?} =
      Enum.reduce(values, {dynamic(true), false}, fn v, {acc, nil_flag} ->
        cond do
          is_nil(v) ->
            {acc, true}

          true ->
            pattern = "%#{v}%"

            new_acc =
              dynamic(
                [{^binding, r}],
                ^acc and not fragment("? ILIKE ?", field(r, ^field), ^pattern)
              )

            {new_acc, nil_flag}
        end
      end)

    if has_nil? do
      dynamic([{^binding, r}], ^dyn and not is_nil(field(r, ^field)))
    else
      dyn
    end
  end

  defp combine_dynamic(acc, condition, :or, binding) do
    dynamic([{^binding, _r}], ^acc or ^condition)
  end

  defp combine_dynamic(acc, condition, :and, binding) do
    dynamic([{^binding, _r}], ^acc and ^condition)
  end

  defp apply_range(query, module, binding, field, values, ctx, negate?) do
    if length(values) != 2 do
      query
    else
      [v1, v2] = values
      low = convert_value_to_field(module, field, v1, ctx.user_timezone)
      high = handle_datetime_range_end(module, field, v2, ctx.user_timezone)

      condition =
        if negate? do
          dynamic(
            [{^binding, r}],
            not fragment("? BETWEEN ? AND ?", field(r, ^field), ^low, ^high)
          )
        else
          dynamic([{^binding, r}], fragment("? BETWEEN ? AND ?", field(r, ^field), ^low, ^high))
        end

      from(r in query, where: ^condition)
    end
  end

  defp apply_temporal(query, module, binding, field, keyword, values, ctx) do
    if length(values) != 1 do
      query
    else
      value = List.first(values)

      converted =
        if keyword in ["before", "before_equal"] do
          handle_datetime_range_end(module, field, value, ctx.user_timezone)
        else
          convert_value_to_field(module, field, value, ctx.user_timezone)
        end

      condition =
        case keyword do
          "after" ->
            dynamic([{^binding, r}], field(r, ^field) > ^converted)

          "after_equal" ->
            dynamic([{^binding, r}], field(r, ^field) >= ^converted)

          "before" ->
            dynamic([{^binding, r}], field(r, ^field) < ^converted)

          "before_equal" ->
            dynamic([{^binding, r}], field(r, ^field) <= ^converted)
        end

      from(r in query, where: ^condition)
    end
  end

  defp handle_datetime_range_end(module, field, value, user_timezone) do
    converted = convert_value_to_field(module, field, value, user_timezone)

    case detect_schema_field?(module, field) do
      :utc_datetime -> Timex.set(converted, second: 59)
      _ -> converted
    end
  end

  defp handle_fields_operation(query, module, binding, field, value, ctx) do
    allowed = ~w(after after_equal before before_equal equal range)
    last = List.last(value)
    has_comp = is_binary(last) and last in allowed

    {comp, raw_vals} = if has_comp, do: {last, Enum.drop(value, -1)}, else: {"equal", value}
    {field_atoms, thresholds} = Enum.split_while(raw_vals, &is_atom/1)

    valid? =
      case field do
        :_fields_diff -> length(field_atoms) >= 2
        :_fields_sum -> field_atoms != []
      end

    if not valid? do
      query
    else
      first_field = hd(field_atoms)
      convert = fn v -> convert_value_to_field(module, first_field, v, ctx.user_timezone) end

      expr =
        if field == :_fields_diff do
          [a, b | _] = field_atoms
          dynamic([{^binding, r}], field(r, ^a) - field(r, ^b))
        else
          Enum.reduce(field_atoms, dynamic([{^binding, r}], 0), fn f, acc ->
            dynamic([{^binding, r}], ^acc + field(r, ^f))
          end)
        end

      cond_dynamic = build_comparison_dynamic(binding, expr, comp, thresholds, convert)

      if ctx.use_or do
        from(r in query, or_where: ^cond_dynamic)
      else
        from(r in query, where: ^cond_dynamic)
      end
    end
  end

  defp build_comparison_dynamic(binding, expr, comp, thresholds, convert) do
    case comp do
      "range" when length(thresholds) >= 2 ->
        low = convert.(Enum.at(thresholds, 0))
        high = convert.(Enum.at(thresholds, 1))
        dynamic([{^binding, r}], ^expr >= ^low and ^expr <= ^high)

      "after" ->
        th = convert.(List.first(thresholds) || 0)
        dynamic([{^binding, r}], ^expr > ^th)

      "after_equal" ->
        th = convert.(List.first(thresholds) || 0)
        dynamic([{^binding, r}], ^expr >= ^th)

      "before" ->
        th = convert.(List.first(thresholds) || 0)
        dynamic([{^binding, r}], ^expr < ^th)

      "before_equal" ->
        th = convert.(List.first(thresholds) || 0)
        dynamic([{^binding, r}], ^expr <= ^th)

      _ ->
        th = convert.(List.first(thresholds) || 0)
        dynamic([{^binding, r}], ^expr == ^th)
    end
  end

  defp non_value?(value) do
    case value do
      nil -> true
      "" -> true
      [] -> true
      -1 -> true
      "-1" -> true
      list when is_list(list) -> Enum.all?(list, &non_value?/1)
      _ -> false
    end
  end

  defp drop_blank_filters(filters) when is_map(filters) do
    filters
    |> Enum.reject(fn {_key, value} -> non_value?(value) end)
    |> Enum.into(%{})
  end

  defp array_type_field?(module, field) do
    case detect_schema_field?(module, field) do
      {:array, _} -> true
      _ -> false
    end
  end

  defp exact_type_field?(module, field) do
    detect_schema_field?(module, field) in @exact_types
  end

  @spec detect_schema_field?(schema :: module(), field :: atom()) ::
          atom() | {atom(), atom()} | nil
  def detect_schema_field?(schema, field) do
    schema.__schema__(:type, field)
  end

  @spec convert_value_to_field(
          module :: module(),
          field :: atom(),
          value :: any(),
          user_timezone :: String.t()
        ) ::
          Date.t()
          | DateTime.t()
          | NaiveDateTime.t()
          | Time.t()
          | integer()
          | float()
          | Decimal.t()
          | boolean()
          | binary()
          | map()
          | nil
  def convert_value_to_field(module, field, value, user_timezone \\ "Etc/UTC") do
    type = detect_schema_field?(module, field)
    do_convert_value(type, value, user_timezone)
  end

  defp do_convert_value(:date, value, _tz) do
    ImportUtils.parse_date!(value)
  end

  defp do_convert_value(:utc_datetime, value, user_timezone) do
    cond do
      is_struct(value, DateTime) ->
        DateTime.shift_zone!(value, "Etc/UTC")

      is_struct(value, NaiveDateTime) ->
        value
        |> DateTime.from_naive!(user_timezone)
        |> DateTime.shift_zone!("Etc/UTC")

      true ->
        case ImportUtils.parse_datetime(value) do
          {:ok, nil} -> nil
          {:ok, %DateTime{} = dt} -> dt
        end
    end
  end

  defp do_convert_value(:naive_datetime, value, _tz) do
    cond do
      is_struct(value, NaiveDateTime) ->
        value

      true ->
        case ImportUtils.parse_datetime(value) do
          {:ok, nil} -> nil
          {:ok, %DateTime{} = dt} -> DateTime.to_naive(dt)
        end
    end
  end

  defp do_convert_value(:time, value, _tz) do
    ImportUtils.parse_to_time(value)
  end

  defp do_convert_value(:integer, value, _tz) do
    ImportUtils.parse_to_integer(value)
  end

  defp do_convert_value(:float, value, _tz) do
    ImportUtils.parse_to_float(value)
  end

  defp do_convert_value(:decimal, value, _tz) do
    ImportUtils.parse_to_decimal(value)
  end

  defp do_convert_value(:boolean, value, _tz) do
    ImportUtils.parse_to_boolean(value)
  end

  defp do_convert_value(:string, value, _tz) do
    ImportUtils.parse_to_string(value)
  end

  defp do_convert_value(:binary, value, _tz), do: value
  defp do_convert_value(:map, value, _tz), do: value
  defp do_convert_value(_, value, _tz), do: value

  @spec ensure_loaded_associations(
          schema :: Ecto.Schema.t(),
          preloads :: [atom()]
        ) :: Ecto.Schema.t()
  def ensure_loaded_associations(schema, preloads \\ []) when is_map(schema) do
    schema
    |> Map.from_struct()
    |> Enum.reduce(schema, fn {key, value}, acc ->
      case value do
        %Ecto.Association.NotLoaded{} ->
          if preloads == [] or key in preloads do
            Repo.preload(acc, [key])
          else
            acc
          end

        _ ->
          acc
      end
    end)
  end

  @spec construct_date_map(
          from_date :: String.t() | nil,
          to_date :: String.t() | nil,
          key :: atom() | String.t()
        ) :: %{optional(atom()) => [String.t()]}
  def construct_date_map(from_date, to_date, key) when is_binary(key) do
    construct_date_map(from_date, to_date, String.to_existing_atom(key))
  end

  def construct_date_map(from_date, to_date, key) when is_atom(key) do
    cond do
      from_date not in ["", nil] and to_date not in ["", nil] ->
        %{key => [from_date, to_date, "range"]}

      from_date not in ["", nil] ->
        %{key => [from_date, "after_equal"]}

      to_date not in ["", nil] ->
        %{key => [to_date, "before_equal"]}

      true ->
        %{key => []}
    end
  end

  @spec construct_date_list(from_date :: String.t() | nil, to_date :: String.t() | nil) :: [
          String.t()
        ]
  def construct_date_list(from_date, to_date) do
    cond do
      from_date not in ["", nil] and to_date not in ["", nil] ->
        [from_date, to_date, "range"]

      from_date not in ["", nil] ->
        [from_date, "after_equal"]

      to_date not in ["", nil] ->
        [to_date, "before_equal"]

      true ->
        []
    end
  end
end
