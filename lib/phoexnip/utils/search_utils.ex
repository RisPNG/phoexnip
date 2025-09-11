defmodule Phoexnip.SearchUtils do
  @moduledoc """
  Dynamic query builder and helper functions for flexible Ecto searches.

  Provides:

    * **`search/1`** – construct and execute an Ecto query from a map of filters (`args`),
      with support for:
        - scalar and list filters (with “range”, “before/after”, “and”/“or” modifiers),
        - nested OR groups (`:_or`, `:_multi_or`),
        - pagination (`page`/`per_page`) or unpaged results,
        - ordering by any field and direction,
        - automatic dropping of sensitive params,
        - timezone‑aware parsing for date and datetime filters,
        - optional association preloading (all or selected),
      returning a map with `:entries`, `:page_number`, `:page_size`, `:total_entries`, and `:total_pages`.

    * **`detect_schema_field?/2`** – introspect an Ecto schema to get the type of a given field.

    * **`convert_value_to_field/4`** – convert arbitrary input (string, struct) into the appropriate
      Ecto type (date, datetime, integer, float, decimal, boolean, etc.), applying the user’s timezone
      when parsing.

    * **`ensure_loaded_associations/2`** – preload any not‑loaded associations on a schema struct,
      either all or a specified subset.

    * **`construct_date_map/3`** and **`construct_date_list/2`** – helpers to build “range”,
      “after_equal”, or “before_equal” filters for date queries.

    * **`extract_square_bracket_from_string/2`** – pull out the Nth “[…]” segment from a string.

  These utilities centralize and standardize how we build, execute, and post‑process complex search
  queries across the application, ensuring consistent filtering, pagination, and type safety.
  """
  import Ecto.Query, warn: false

  alias Phoexnip.Repo
  alias Phoexnip.ImportUtils

  @doc """
  ## Parameters

  * `args` (`%{field => value}`) – filters to apply.
    • Scalars become `WHERE field ILIKE '%value%'` for string‐like types, or `field == value` for numeric/date/boolean fields.
    • Lists may carry a trailing keyword (`"range"`, `"after"`, `"after_equal"`, `"before"`, `"before_equal"`, `"and"`, `"or"`) to control comparison logic.
    * Special keys:
      - `:_or`       – map of field→value to OR together at the top level
      - `:_multi_or` – list of maps; each map’s filters are ANDed together, then ORed with the others

  * `pagination` (`%{page: integer, per_page: integer}` or any other map) –
    If it includes `:page` and `:per_page`, returns a paged result; otherwise returns all matches.

  * `module` (`Ecto.Schema` module) – the schema to query.

  * `use_or` (`boolean`) – when `true`, list filters default to OR rather than AND (for un‐keyworded lists).

  * `drop_args` (`[atom]`) – additional keys to remove from `args` (beyond default sensitive fields) before filtering.

  * `order_by` (`atom`) – field to sort by (default `:id`).

  * `user_timezone` (`String.t`) – timezone for converting string inputs to `:date`/`:utc_datetime` (default `"Asia/Kuala_Lumpur"`).

  * `preload` (`true | false | [] | [assoc | {assoc, opts}]`) –
    - `true` preloads **all** associations via `ImportUtils.preload_all(module)`,
    - a non-empty list preloads only those associations,
    - `false` or `[]` means no preloading.

  * `order_method` (`:asc | :desc`) – sort direction (default `:asc`).

  ## Description

  * **Field Filters**
    - Scalars → simple equality or ILIKE
    - Lists → range, before/after, AND/OR combinators
    - Nested grouping via `:_or` and `:_multi_or`

  * **Pagination & Ordering**
    - Page results via `page`/`per_page` or return all entries
    - Sort by any field/direction

  * **Argument Sanitization**
    - Drops `[:hashed_password, :password, :current_password, :password_confirmation]` plus any in `drop_args`
    - Base64-decodes values via `/1`

  * **Timezone Handling**
    - Converts string inputs to date/datetime in `user_timezone`

  * **Associations Preload**
    - `true` → all associations
    - list → specified only
    - `false`/`[]` → none

  ## Return

  A map with:

  * `:entries`       – list of `%module{}` structs (preloaded if requested)
  * `:page_number`   – current page (always `1` if unpaged)
  * `:page_size`     – number of entries returned
  * `:total_entries` – total matching rows
  * `:total_pages`   – total pages (≥ 1)

  ## Examples

  ```elixir
  # OR‐based list filter, custom drop_args, preload comments+author
  SearchModule.search(
  %{status: "open", tags: ["elixir", "phoenix", "or"]},
  %{page: 2, per_page: 10},
  MyApp.Post,
  true,
  [:secret_flag],
  :inserted_at,
  "UTC",
  [:comments, :author],
  :desc
  )

  # No pagination, no preloads
  SearchModule.search(%{}, %{}, MyApp.User, false, [], :id, "UTC", [], :asc)

  # Preload everything
  SearchModule.search(%{}, %{}, MyApp.User, false, [], :id, "UTC", true)
  ```
  """
  @spec search(
          opts :: [
            module: module(),
            args: %{optional(atom()) => any()},
            pagination: %{optional(:page) => pos_integer(), optional(:per_page) => pos_integer()},
            use_or: boolean(),
            drop_args: [atom()],
            order_by: atom(),
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
    args = Keyword.get(opts, :args, %{})
    pagination = Keyword.get(opts, :pagination, %{})
    module = Keyword.fetch!(opts, :module)
    use_or = Keyword.get(opts, :use_or, false)
    drop_args = Keyword.get(opts, :drop_args, [])
    order_by = Keyword.get(opts, :order_by, :id)
    user_timezone = Keyword.get(opts, :user_timezone, "Asia/Kuala_Lumpur")
    preload = Keyword.get(opts, :preload, [])
    order_method = Keyword.get(opts, :order_method, :asc)

    # Clean and parse arguments
    cleaned_args = clean_and_parse_args(args, drop_args)
    {or_filters, remaining_filters} = Map.pop(cleaned_args, :_or)
    {multi_or_filters, remaining_filters} = Map.pop(remaining_filters, :_multi_or)

    base_query = from(p in module, as: :p)

    # Apply regular filters
    {filtered_query, joined_associations} =
      apply_filters(remaining_filters, base_query, module, user_timezone, use_or)

    # Apply OR filters
    {query_with_or, joined_associations} =
      apply_or_filters(or_filters, filtered_query, joined_associations, module, user_timezone)

    # Apply multi-OR filters
    {query_with_multi_or, joined_associations} =
      apply_multi_or_filters(
        multi_or_filters,
        query_with_or,
        joined_associations,
        module,
        user_timezone
      )

    # Handle ordering
    {final_query, total_count_query} =
      prepare_final_query(
        query_with_multi_or,
        joined_associations,
        module,
        order_by,
        order_method
      )

    # Execute query with pagination
    execute_query_with_pagination(final_query, total_count_query, pagination, preload, module)
  end

  # Helper function to clean and parse arguments
  defp clean_and_parse_args(args, drop_args) do
    drop_fields =
      [:hashed_password, :password, :current_password, :password_confirmation] ++ drop_args

    args
    |> Map.drop(drop_fields)
    |> parse_association_keys()
  end

  # Helper function to parse association keys (field@association)
  defp parse_association_keys(args) do
    Enum.into(args, %{}, fn {key, value} ->
      if String.contains?(to_string(key), "@") do
        [field, association] = String.split(to_string(key), "@", parts: 2)
        {{String.to_atom(field), String.to_atom(association)}, value}
      else
        {key, value}
      end
    end)
  end

  # Helper function to apply regular filters
  defp apply_filters(filters, base_query, module, user_timezone, use_or) do
    Enum.reduce(filters, {base_query, MapSet.new()}, fn
      {{field, association}, value}, {acc_query, joined} ->
        if non_value?(value) do
          {acc_query, joined}
        else
          query_with_join = ensure_association_joined(acc_query, association, joined)
          assoc_module = get_assoc_module(module, association)

          new_query =
            build_field_query(
              query_with_join,
              assoc_module,
              association,
              field,
              value,
              user_timezone,
              use_or
            )

          {new_query, MapSet.put(joined, association)}
        end

      {field, value}, {acc_query, joined} ->
        if non_value?(value) do
          {acc_query, joined}
        else
          new_query =
            build_field_query(
              acc_query,
              module,
              :p,
              field,
              value,
              user_timezone,
              use_or
            )

          {new_query, joined}
        end
    end)
  end

  # Helper function to apply OR filters
  defp apply_or_filters(nil, query, joined_associations, _module, _user_timezone) do
    {query, joined_associations}
  end

  defp apply_or_filters(or_filters, query, joined_associations, module, user_timezone) do
    parsed_or_filters = parse_association_keys(or_filters)

    # Drop association filters whose values are blank to avoid unnecessary joins
    filtered_or_filters = drop_blank_assoc_filters(parsed_or_filters)

    # If nothing meaningful remains, do not alter the query
    if map_size(filtered_or_filters) == 0 do
      {query, joined_associations}
    else
      # Ensure only needed associations are joined
      {query_with_joins, updated_joined} =
        ensure_or_associations_joined(query, filtered_or_filters, joined_associations)

      # Build OR dynamic query from filtered map
      or_dynamic = build_or_dynamic(filtered_or_filters, module, user_timezone)

      {from(r in query_with_joins, where: ^or_dynamic), updated_joined}
    end
  end

  # Helper function to apply multi-OR filters
  defp apply_multi_or_filters(nil, query, joined_associations, _module, _user_timezone) do
    {query, joined_associations}
  end

  defp apply_multi_or_filters(multi_or_filters, query, joined_associations, module, user_timezone) do
    parsed_multi_or = Enum.map(multi_or_filters, &parse_association_keys/1)

    # Drop blank association filters within each group; remove empty groups entirely
    filtered_groups =
      parsed_multi_or
      |> Enum.map(&drop_blank_assoc_filters/1)
      |> Enum.reject(&(map_size(&1) == 0))

    if filtered_groups == [] do
      {query, joined_associations}
    else
      # Ensure only needed associations are joined
      {query_with_joins, updated_joined} =
        ensure_multi_or_associations_joined(query, filtered_groups, joined_associations)

      # Build multi-OR dynamic query
      or_dynamic = build_multi_or_dynamic(filtered_groups, module, user_timezone)

      {from(r in query_with_joins, where: ^or_dynamic), updated_joined}
    end
  end

  # Helper function to ensure association is joined
  defp ensure_association_joined(query, association, joined) do
    if MapSet.member?(joined, association) do
      query
    else
      from(q in query, join: a in assoc(q, ^association), as: ^association)
    end
  end

  # Helper function to ensure OR filter associations are joined
  defp ensure_or_associations_joined(query, parsed_or_filters, joined_associations) do
    # Only consider associations with non-blank values
    or_associations = extract_associations_from_filters(parsed_or_filters)

    Enum.reduce(MapSet.to_list(or_associations), {query, joined_associations}, fn assoc,
                                                                                  {q, joined} ->
      if MapSet.member?(joined, assoc) do
        {q, joined}
      else
        {from(sq in q, join: a in assoc(sq, ^assoc), as: ^assoc), MapSet.put(joined, assoc)}
      end
    end)
  end

  # Helper function to ensure multi-OR filter associations are joined
  defp ensure_multi_or_associations_joined(query, parsed_multi_or, joined_associations) do
    multi_or_associations =
      parsed_multi_or
      |> Enum.flat_map(&extract_associations_from_filters/1)
      |> MapSet.new()

    Enum.reduce(MapSet.to_list(multi_or_associations), {query, joined_associations}, fn assoc,
                                                                                        {q,
                                                                                         joined} ->
      if MapSet.member?(joined, assoc) do
        {q, joined}
      else
        {from(sq in q, join: a in assoc(sq, ^assoc), as: ^assoc), MapSet.put(joined, assoc)}
      end
    end)
  end

  # Helper function to extract associations from filters
  defp extract_associations_from_filters(filters) do
    filters
    |> Enum.reduce(MapSet.new(), fn
      {{_field, assoc}, value}, acc ->
        if non_value?(value) do
          acc
        else
          MapSet.put(acc, assoc)
        end

      {_k, _v}, acc ->
        acc
    end)
  end

  # Helper function to build OR dynamic query
  defp build_or_dynamic(parsed_or_filters, module, user_timezone) do
    Enum.reduce(parsed_or_filters, dynamic(false), fn
      {{field, association}, value}, acc ->
        # Skip building conditions for non-values
        if non_value?(value) do
          acc
        else
          assoc_module = get_assoc_module(module, association)
          comp = build_field_condition(assoc_module, association, field, value, user_timezone)
          dynamic([p], ^acc or ^comp)
        end

      {field, value}, acc ->
        if non_value?(value) do
          acc
        else
          comp = build_field_condition(module, :p, field, value, user_timezone)
          dynamic([p], ^acc or ^comp)
        end
    end)
  end

  # Helper function to build multi-OR dynamic query
  defp build_multi_or_dynamic(parsed_multi_or, module, user_timezone) do
    Enum.reduce(parsed_multi_or, dynamic(false), fn group_map, or_acc ->
      group_dynamic = build_group_and_dynamic(group_map, module, user_timezone)
      dynamic([p], ^or_acc or ^group_dynamic)
    end)
  end

  # Helper function to build group AND dynamic query
  defp build_group_and_dynamic(group_map, module, user_timezone) do
    Enum.reduce(group_map, dynamic(true), fn
      {{field, association}, value}, and_acc ->
        # Skip non-values to avoid unnecessary joins and tautologies
        if non_value?(value) do
          and_acc
        else
          assoc_module = get_assoc_module(module, association)
          comp = build_field_condition(assoc_module, association, field, value, user_timezone)
          dynamic([p], ^and_acc and ^comp)
        end

      {field, value}, and_acc ->
        if non_value?(value) do
          and_acc
        else
          comp = build_field_condition(module, :p, field, value, user_timezone)
          dynamic([p], ^and_acc and ^comp)
        end
    end)
  end

  # Helper function to build field condition dynamic
  defp build_field_condition(module, binding, field, value, user_timezone) do
    if detect_schema_field?(module, field) in [
         :integer,
         :float,
         :decimal,
         :date,
         :utc_datetime,
         :boolean,
         :id
       ] do
      dynamic(
        [{^binding, a}],
        field(a, ^field) == ^convert_value_to_field(module, field, value, user_timezone)
      )
    else
      dynamic(
        [{^binding, a}],
        fragment("? ILIKE ?", field(a, ^field), ^("%" <> to_string(value) <> "%"))
      )
    end
  end

  # Helper function to prepare final query with ordering
  defp prepare_final_query(query, joined_associations, module, order_by, order_method) do
    {order_by_field, order_by_binding, preliminary_query, _joined_associations} =
      handle_order_by_association(query, joined_associations, module, order_by)

    final_query =
      optimize_query_with_joins(
        preliminary_query,
        joined_associations,
        module,
        order_by_binding
      )

    ordered_query =
      from p in final_query,
        order_by: [{^order_method, field(as(^order_by_binding), ^order_by_field)}]

    # Return both the final query and the query for counting
    {ordered_query, query}
  end

  # Helper function to handle order by association
  defp handle_order_by_association(query, joined_associations, _module, order_by) do
    if String.contains?(to_string(order_by), "@") do
      [field_str, assoc_str] = String.split(to_string(order_by), "@", parts: 2)
      field = String.to_atom(field_str)
      association = String.to_atom(assoc_str)

      query_with_join = ensure_association_joined(query, association, joined_associations)
      {field, association, query_with_join, MapSet.put(joined_associations, association)}
    else
      {order_by, :p, query, joined_associations}
    end
  end

  # Helper function to optimize query with joins for ordering
  defp optimize_query_with_joins(preliminary_query, joined_associations, module, order_by_binding) do
    if MapSet.size(joined_associations) > 0 and order_by_binding != :p do
      ids_subq =
        from q in preliminary_query,
          select: %{id: field(as(:p), :id)},
          distinct: true

      from p in module,
        as: :p,
        join: s in subquery(ids_subq),
        on: p.id == s.id,
        join: a in assoc(p, ^order_by_binding),
        as: ^order_by_binding
    else
      if MapSet.size(joined_associations) > 0 do
        from q in preliminary_query, distinct: true
      else
        preliminary_query
      end
    end
  end

  # Helper function to execute query with pagination
  defp execute_query_with_pagination(final_query, count_query, pagination, preload, module) do
    case pagination do
      %{page: page, per_page: per_page} ->
        total_entries =
          Repo.one(from q in count_query, select: count(field(as(:p), :id), :distinct))

        results =
          final_query
          |> offset(^((page - 1) * per_page))
          |> limit(^per_page)
          |> Repo.all()
          |> apply_preload(preload, module)

        total_pages = max(ceil(total_entries / per_page), 1)

        %{
          entries: results,
          page_number: page,
          page_size: per_page,
          total_entries: total_entries,
          total_pages: total_pages
        }

      _ ->
        results =
          final_query
          |> Repo.all()
          |> apply_preload(preload, module)

        total_entries =
          Repo.one(from q in count_query, select: count(field(as(:p), :id), :distinct))

        %{
          entries: results,
          page_number: 1,
          page_size: length(results),
          total_entries: total_entries,
          total_pages: 1
        }
    end
  end

  # Helper function to apply preload
  defp apply_preload(results, preload, module) do
    cond do
      preload === true ->
        results |> Repo.preload(ImportUtils.preload_all(module))

      is_list(preload) and length(preload) > 0 ->
        results |> Repo.preload(preload)

      true ->
        results
    end
  end

  defp get_assoc_module(module, assoc_atom) do
    case module.__schema__(:association, assoc_atom) do
      nil ->
        raise "Association :#{assoc_atom} not found on module #{module}"

      assoc ->
        assoc.related
    end
  end

  # Keep the existing build_field_query function for complex field operations
  defp build_field_query(acc_query, module, binding, field, value, user_timezone, use_or) do
    cond do
      field in [:_fields_diff, :_fields_sum] and is_list(value) ->
        handle_fields_operation(acc_query, module, binding, field, value, user_timezone, use_or)

      non_value?(value) ->
        acc_query

      is_list(value) ->
        handle_list_value(acc_query, module, binding, field, value, user_timezone, use_or)

      true ->
        handle_single_value(acc_query, module, binding, field, value, user_timezone, use_or)
    end
  end

  # Treat these values as "blank" for filter and association-join purposes
  defp non_value?(value) do
    case value do
      nil ->
        true

      "" ->
        true

      [] ->
        true

      -1 ->
        true

      "-1" ->
        true

      list when is_list(list) ->
        # Check if list only contains non-values
        Enum.all?(list, &non_value?/1)

      _ ->
        false
    end
  end

  # Remove association-based filters (like {field, assoc}) whose value is blank
  defp drop_blank_assoc_filters(filters) when is_map(filters) do
    filters
    |> Enum.reject(fn
      # Remove association-based filters with blank values
      {{_field, _assoc}, value} -> non_value?(value)
      # Remove regular field filters with blank values
      {_field, value} -> non_value?(value)
    end)
    |> Enum.into(%{})
  end

  # Helper functions for specific field operations (keeping the existing complex logic)
  defp handle_fields_operation(acc_query, module, binding, field, value, user_timezone, use_or) do
    # Keep existing _fields_diff and _fields_sum logic
    allowed = ~w(after after_equal before before_equal equal range)
    last = List.last(value)
    has_comp = is_binary(last) and last in allowed

    {comp, raw_vals} =
      if has_comp do
        {last, Enum.drop(value, -1)}
      else
        {"equal", value}
      end

    {field_atoms, thresholds} = Enum.split_while(raw_vals, &is_atom/1)

    cond do
      field == :_fields_diff and length(field_atoms) < 2 ->
        acc_query

      field == :_fields_sum and field_atoms == [] ->
        acc_query

      true ->
        first_field = hd(field_atoms)
        convert = fn v -> convert_value_to_field(module, first_field, v, user_timezone) end

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

        if use_or do
          from r in acc_query, or_where: ^cond_dynamic
        else
          from r in acc_query, where: ^cond_dynamic
        end
    end
  end

  defp build_comparison_dynamic(binding, expr, comp, thresholds, convert) do
    case comp do
      "range" ->
        if length(thresholds) >= 2 do
          low = convert.(Enum.at(thresholds, 0))
          high = convert.(Enum.at(thresholds, 1))
          dynamic([{^binding, r}], ^expr >= ^low and ^expr <= ^high)
        else
          dynamic(true)
        end

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

      "equal" ->
        th = convert.(List.first(thresholds) || 0)
        dynamic([{^binding, r}], ^expr == ^th)
    end
  end

  defp handle_list_value(acc_query, module, binding, field, value, user_timezone, use_or) do
    filtered_value = Enum.reject(value, &non_value?/1)

    if filtered_value == [] do
      acc_query
    else
      {keywords, values} = extract_list_keywords(value)

      if values == [] do
        acc_query
      else
        field_condition =
          build_list_field_condition(binding, module, field, keywords, values, user_timezone)

        apply_list_condition(
          acc_query,
          field_condition,
          keywords,
          values,
          use_or,
          module,
          field,
          binding,
          user_timezone
        )
      end
    end
  end

  defp extract_list_keywords(value) do
    case List.last(value) do
      "range" -> {"range", Enum.drop(value, -1)}
      "not_range" -> {"not_range", Enum.drop(value, -1)}
      "after" -> {"after", Enum.drop(value, -1)}
      "after_equal" -> {"after_equal", Enum.drop(value, -1)}
      "before" -> {"before", Enum.drop(value, -1)}
      "before_equal" -> {"before_equal", Enum.drop(value, -1)}
      "and" -> {"and", Enum.drop(value, -1)}
      "or" -> {"or", Enum.drop(value, -1)}
      "exact_and" -> {"exact_and", Enum.drop(value, -1)}
      "exact_or" -> {"exact_or", Enum.drop(value, -1)}
      "exact_not" -> {"exact_not", Enum.drop(value, -1)}
      "not" -> {"not", Enum.drop(value, -1)}
      _ -> {nil, value}
    end
  end

  defp build_list_field_condition(binding, module, field, keywords, values, user_timezone) do
    cond do
      keywords == "not_range" ->
        build_not_range_condition(binding, module, field, values, user_timezone)

      keywords == "not" ->
        build_not_condition(binding, module, field, values, user_timezone)

      keywords == "exact_not" ->
        build_exact_not_condition(binding, module, field, values, user_timezone)

      keywords == "or" ->
        build_or_condition(binding, module, field, values, user_timezone)

      keywords == "exact_or" ->
        build_exact_or_condition(binding, module, field, values, user_timezone)

      keywords == "exact_and" ->
        build_exact_and_condition(binding, module, field, values, user_timezone)

      true ->
        build_and_condition(binding, module, field, values, user_timezone)
    end
  end

  defp build_not_range_condition(binding, module, field, values, user_timezone) do
    if length(values) == 2 do
      dynamic(
        [{^binding, r}],
        not fragment(
          "? BETWEEN ? AND ?",
          field(r, ^field),
          ^convert_value_to_field(module, field, List.first(values), user_timezone),
          ^handle_datetime_range_end(module, field, List.last(values), user_timezone)
        )
      )
    else
      dynamic(true)
    end
  end

  defp build_not_condition(binding, module, field, values, user_timezone) do
    if length(values) == 1 and is_exact_type_field?(module, field) do
      dynamic(
        [{^binding, r}],
        field(r, ^field) !=
          ^convert_value_to_field(module, field, List.first(values), user_timezone)
      )
    else
      if is_exact_type_field?(module, field) do
        converted_values =
          Enum.map(values, fn v ->
            convert_value_to_field(module, field, v, user_timezone)
          end)

        dynamic([{^binding, r}], field(r, ^field) not in ^converted_values)
      else
        Enum.reduce(values, dynamic(true), fn v, dyn_acc ->
          dynamic(
            [{^binding, r}],
            ^dyn_acc and
              not fragment("? ILIKE ?", field(r, ^field), ^("%" <> to_string(v) <> "%"))
          )
        end)
      end
    end
  end

  defp build_exact_not_condition(binding, module, field, values, user_timezone) do
    if is_exact_type_field?(module, field) do
      converted_values =
        Enum.map(values, fn v ->
          convert_value_to_field(module, field, v, user_timezone)
        end)

      dynamic([{^binding, r}], field(r, ^field) not in ^converted_values)
    else
      # Force exact match exclusion for string fields
      Enum.reduce(values, dynamic(true), fn v, dyn_acc ->
        dynamic(
          [{^binding, r}],
          ^dyn_acc and field(r, ^field) != ^v
        )
      end)
    end
  end

  defp build_or_condition(binding, module, field, values, user_timezone) do
    Enum.reduce(values, dynamic(false), fn v, dyn_acc ->
      if is_exact_type_field?(module, field) do
        dynamic(
          [{^binding, r}],
          ^dyn_acc or field(r, ^field) == ^convert_value_to_field(module, field, v, user_timezone)
        )
      else
        dynamic(
          [{^binding, r}],
          ^dyn_acc or fragment("? ILIKE ?", field(r, ^field), ^("%" <> to_string(v) <> "%"))
        )
      end
    end)
  end

  defp build_exact_or_condition(binding, module, field, values, user_timezone) do
    Enum.reduce(values, dynamic(false), fn v, dyn_acc ->
      if is_exact_type_field?(module, field) do
        dynamic(
          [{^binding, r}],
          ^dyn_acc or field(r, ^field) == ^convert_value_to_field(module, field, v, user_timezone)
        )
      else
        # Force exact match for string fields
        dynamic(
          [{^binding, r}],
          ^dyn_acc or field(r, ^field) == ^v
        )
      end
    end)
  end

  defp build_and_condition(binding, module, field, values, user_timezone) do
    Enum.reduce(values, dynamic(true), fn v, dyn_acc ->
      if is_exact_type_field?(module, field) do
        dynamic(
          [{^binding, r}],
          ^dyn_acc and
            field(r, ^field) == ^convert_value_to_field(module, field, v, user_timezone)
        )
      else
        dynamic(
          [{^binding, r}],
          ^dyn_acc and fragment("? ILIKE ?", field(r, ^field), ^("%" <> to_string(v) <> "%"))
        )
      end
    end)
  end

  defp build_exact_and_condition(binding, module, field, values, user_timezone) do
    Enum.reduce(values, dynamic(true), fn v, dyn_acc ->
      if is_exact_type_field?(module, field) do
        dynamic(
          [{^binding, r}],
          ^dyn_acc and
            field(r, ^field) == ^convert_value_to_field(module, field, v, user_timezone)
        )
      else
        # Force exact match for string fields
        dynamic(
          [{^binding, r}],
          ^dyn_acc and field(r, ^field) == ^v
        )
      end
    end)
  end

  defp apply_list_condition(
         acc_query,
         field_condition,
         keywords,
         values,
         use_or,
         module,
         field,
         binding,
         user_timezone
       ) do
    case keywords do
      "not_range" ->
        if length(values) == 2 do
          from r in acc_query, where: ^field_condition
        else
          acc_query
        end

      "not" ->
        from r in acc_query, where: ^field_condition

      "exact_not" ->
        from r in acc_query, where: ^field_condition

      "range" ->
        apply_range_condition(acc_query, values, module, field, binding, user_timezone)

      keyword when keyword in ["after", "after_equal", "before", "before_equal"] ->
        apply_temporal_condition(
          acc_query,
          keyword,
          values,
          module,
          field,
          binding,
          user_timezone
        )

      "or" ->
        from r in acc_query, where: ^field_condition

      "exact_or" ->
        from r in acc_query, where: ^field_condition

      "and" ->
        from r in acc_query, where: ^field_condition

      "exact_and" ->
        from r in acc_query, where: ^field_condition

      _ ->
        if use_or do
          from r in acc_query, or_where: ^field_condition
        else
          from r in acc_query, where: ^field_condition
        end
    end
  end

  defp apply_range_condition(acc_query, values, module, field, binding, user_timezone) do
    if length(values) == 2 do
      from [{^binding, r}] in acc_query,
        where:
          fragment(
            "? BETWEEN ? AND ?",
            field(r, ^field),
            ^convert_value_to_field(module, field, List.first(values), user_timezone),
            ^handle_datetime_range_end(module, field, List.last(values), user_timezone)
          )
    else
      acc_query
    end
  end

  defp apply_temporal_condition(acc_query, keyword, values, module, field, binding, user_timezone) do
    case keyword do
      "after" ->
        if length(values) == 1 do
          from [{^binding, r}] in acc_query,
            where:
              fragment(
                "? > ?",
                field(r, ^field),
                ^convert_value_to_field(module, field, List.first(values), user_timezone)
              )
        else
          acc_query
        end

      "after_equal" ->
        if length(values) == 1 do
          from [{^binding, r}] in acc_query,
            where:
              fragment(
                "? >= ?",
                field(r, ^field),
                ^convert_value_to_field(module, field, List.first(values), user_timezone)
              )
        else
          acc_query
        end

      "before" ->
        if length(values) == 1 do
          from [{^binding, r}] in acc_query,
            where:
              fragment(
                "? < ?",
                field(r, ^field),
                ^handle_datetime_range_end(module, field, List.first(values), user_timezone)
              )
        else
          acc_query
        end

      "before_equal" ->
        if length(values) == 1 do
          from [{^binding, r}] in acc_query,
            where:
              fragment(
                "? <= ?",
                field(r, ^field),
                ^handle_datetime_range_end(module, field, List.first(values), user_timezone)
              )
        else
          acc_query
        end

      _ ->
        acc_query
    end
  end

  defp handle_single_value(acc_query, module, binding, field, value, user_timezone, use_or) do
    single_condition = build_single_value_condition(binding, module, field, value, user_timezone)

    if use_or do
      from r in acc_query, or_where: ^single_condition
    else
      from r in acc_query, where: ^single_condition
    end
  end

  defp build_single_value_condition(binding, module, field, value, user_timezone) do
    if is_exact_type_field?(module, field) do
      dynamic(
        [{^binding, r}],
        field(r, ^field) == ^convert_value_to_field(module, field, value, user_timezone)
      )
    else
      dynamic(
        [{^binding, r}],
        fragment("? ILIKE ?", field(r, ^field), ^("%" <> to_string(value) <> "%"))
      )
    end
  end

  # Helper functions for field type checking
  defp is_exact_type_field?(module, field) do
    detect_schema_field?(module, field) in [
      :integer,
      :float,
      :decimal,
      :date,
      :utc_datetime,
      :boolean,
      :id
    ]
  end

  defp handle_datetime_range_end(module, field, value, user_timezone) do
    case detect_schema_field?(module, field) do
      :utc_datetime ->
        Timex.set(convert_value_to_field(module, field, value, user_timezone), second: 59)

      _ ->
        convert_value_to_field(module, field, value, user_timezone)
    end
  end

  # Keep all existing utility functions unchanged
  @spec detect_schema_field?(schema :: module(), field :: atom()) :: atom() | nil
  def detect_schema_field?(schema, field) do
    schema.__schema__(:type, field)
  end

  # Keep existing convert_value_to_field function unchanged
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
  def convert_value_to_field(module, field, value, user_timezone \\ "Asia/Kuala_Lumpur") do
    case detect_schema_field?(module, field) do
      # Date conversion
      :date ->
        cond do
          is_struct(value, Date) ->
            value

          is_binary(value) and String.trim(value) != "" ->
            case Date.from_iso8601(value) do
              {:ok, d} -> d
              _ -> nil
            end

          true ->
            nil
        end

      # UTC DateTime conversion
      :utc_datetime ->
        cond do
          is_struct(value, DateTime) ->
            DateTime.shift_zone!(value, "Etc/UTC")

          is_struct(value, NaiveDateTime) ->
            value
            |> DateTime.from_naive!(user_timezone)
            |> DateTime.shift_zone!("Etc/UTC")

          is_binary(value) and String.trim(value) != "" ->
            value
            |> Phoexnip.DateUtils.ensure_datetime_format()
            |> Timex.parse("{ISO:Extended}")
            |> case do
              {:ok, dt} ->
                Timex.to_datetime(dt, user_timezone)
                |> DateTime.shift_zone!("Etc/UTC")

              _ ->
                nil
            end

          true ->
            nil
        end

      # Naive DateTime conversion
      :naive_datetime ->
        cond do
          is_struct(value, NaiveDateTime) ->
            value

          is_binary(value) and String.trim(value) != "" ->
            case NaiveDateTime.from_iso8601(value) do
              {:ok, ndt} -> ndt
              _ -> nil
            end

          true ->
            nil
        end

      # Time conversion
      :time ->
        cond do
          is_struct(value, Time) ->
            value

          is_binary(value) and String.trim(value) != "" ->
            case Time.from_iso8601(value) do
              {:ok, t} -> t
              _ -> nil
            end

          true ->
            nil
        end

      # Integer conversion
      :integer when is_binary(value) ->
        case Integer.parse(value) do
          {int, _} -> int
          _ -> nil
        end

      # Float conversion
      :float when is_binary(value) ->
        case Float.parse(value) do
          {flt, _} -> flt
          _ -> nil
        end

      # Decimal conversion
      :decimal when is_binary(value) ->
        case Decimal.parse(value) do
          {dec, _} -> dec
          _ -> nil
        end

      :decimal when is_number(value) ->
        Decimal.new(to_string(value))

      # Boolean conversion
      :boolean ->
        cond do
          is_boolean(value) ->
            value

          is_binary(value) ->
            case String.downcase(String.trim(value)) do
              "true" -> true
              "false" -> false
              _ -> nil
            end

          true ->
            nil
        end

      # String conversion
      :string ->
        if is_binary(value), do: value, else: to_string(value)

      # For binary fields, leave as is if already a binary
      :binary ->
        if is_binary(value), do: value, else: value

      # For map fields, assume value is already a map (or leave unchanged)
      :map ->
        if is_map(value), do: value, else: value

      # Catch-all: return the value unmodified
      _ ->
        value
    end
  end

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
          # If specific preloads are provided, only preload those
          preloads_to_load =
            if preloads == [] or key in preloads do
              [key]
            else
              []
            end

          if preloads_to_load != [] do
            Repo.preload(acc, preloads_to_load)
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
          key :: atom()
        ) :: %{optional(atom()) => [String.t()]}
  def construct_date_map(from_date, to_date, key) when is_atom(key) do
    cond do
      from_date not in ["", nil] and to_date not in ["", nil] ->
        %{key => [from_date, to_date, "range"]}

      from_date not in ["", nil] and to_date in ["", nil] ->
        %{key => [from_date, "after_equal"]}

      from_date in ["", nil] and to_date not in ["", nil] ->
        %{key => [to_date, "before_equal"]}

      true ->
        %{key => []}
    end
  end

  @spec construct_date_map(
          from_date :: String.t() | nil,
          to_date :: String.t() | nil,
          key :: String.t()
        ) :: %{optional(atom()) => [String.t()]}
  def construct_date_map(from_date, to_date, key) when is_binary(key) do
    construct_date_map(from_date, to_date, String.to_existing_atom(key))
  end

  @spec construct_date_list(
          from_date :: String.t() | nil,
          to_date :: String.t() | nil
        ) :: [String.t()]
  def construct_date_list(from_date, to_date) do
    cond do
      from_date not in ["", nil] and to_date not in ["", nil] ->
        [from_date, to_date, "range"]

      from_date not in ["", nil] and to_date in ["", nil] ->
        [from_date, "after_equal"]

      from_date in ["", nil] and to_date not in ["", nil] ->
        [to_date, "before_equal"]

      true ->
        []
    end
  end

  @spec extract_square_bracket_from_string(
          id :: String.t(),
          at :: non_neg_integer()
        ) :: String.t() | nil
  def extract_square_bracket_from_string(id, at) do
    regex = ~r/\[([^\]]*)\]/

    matches = Regex.scan(regex, id)

    case Enum.at(matches, at) do
      [_, ""] -> nil
      [_, val] -> val
      nil -> nil
    end
  end
end
