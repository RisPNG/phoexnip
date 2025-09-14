defmodule Phoexnip.ImportUtils do
  @moduledoc """
  Utilities for importing and transforming data from external sources.

  This module provides a suite of functions to:

    * `parse_xl_with_header/3` — Safely consume an Excel upload via Phoenix LiveView, read a specified sheet,
      extract header and data rows, handle errors, and normalize column order across multiple files.
    * `parse_datetime/1` — Convert various inputs (Excel serial dates, ISO‑8601 strings, NaiveDateTime, Date)
      into a UTC `DateTime`; returns `{:ok, datetime}` or `nil`.
    * `parse_product_number/1` — Normalize numeric or numeric‑like inputs into integer strings or return `nil`.
    * `parse_to_string/1` — Render floats, integers, binaries, lists, booleans, `DateTime`/`Date` into string form.
    * `list_submatch?/2` — Case‑insensitive, trimmed substring matching: ensures every string in one list
      appears in at least one string of another list.
    * `bulk_upsert/4` — Perform transactional bulk upserts on Ecto schemas with nested associations,
      intelligent timestamp handling, conflict‑resolution, and optional association deletion.
    * `preload_all/3` — Recursively generate Ecto preload specifications (excluding `belongs_to`),
      with optional ordering per association.
    * `transform_search_to_form_struct/2` — Transform SearchUtils results or structs into
      form‑friendly maps with string keys, handling nested associations.
    * `enum_header/3` — Retrieve values from a row by header names or groups, defaulting to `""` if missing.

  ## Examples

      iex> ImportUtils.parse_xl_with_header(socket)
      {:ok, {["id", "name"], [["1", "Alice"], ["2", "Bob"]]}}

      iex> ImportUtils.parse_datetime("44601.75")
      {:ok, ~U[2022-01-31 18:00:00Z]}

      iex> ImportUtils.parse_product_number(1234.56)
      "1234"

      iex> ImportUtils.list_submatch?(["foo", "bar"], [" foOBAZ ", "quxBARqux"])
      true

      iex> ImportUtils.bulk_upsert(Phoexnip.Product, [%{"name" => "Widget"}])
      {:ok, %{updated_entities: [%Phoexnip.Product{...}], original_entities: %{}}}

  """

  import Ecto.Query, warn: false
  import Phoenix.LiveView.Upload

  alias Phoexnip.SearchUtils
  alias Phoexnip.Repo

  @doc """
  Reads an Excel file from a Phoenix socket file upload and extracts rows and header data from the specified sheet.

  This function is designed to help prevent the following GenServer error:

      GenServer #PID<0.1529.0> terminating
      ** (stop) exited in: GenServer.call(#PID<0.1539.0>, :consume_done, :infinity)
          ** (EXIT) no process: the process is not alive or there's no process currently associated
          with the given name, possibly because its application isn't started

  It works by using `consume_uploaded_entries/3` to properly manage the file processing lifecycle, validating and reading the Excel package with `XlsxReader`, and retrieving the rows and header data from the desired sheet (defaulting to the first sheet).

  ## Parameters
    - socket: The Phoenix socket containing the uploaded Excel file(s).
    - sheet_idx: (optional) The index of the Excel sheet to read. Defaults to 0 (First sheet).
    - header_row_idx: (optional) The index of the header row in the Excel sheet. Defaults to 0 (First row).

  ## Returns
  Returns the rows and headers from the specified sheet in the uploaded Excel file.
  """
  @spec parse_xl_with_header(
          socket :: Phoenix.LiveView.Socket.t(),
          sheet_idx :: non_neg_integer(),
          header_row_idx :: non_neg_integer()
        ) ::
          {:ok, {list(String.t()), list(list(any()))}}
          | {:error, String.t()}
  def parse_xl_with_header(socket, sheet_idx \\ 0, header_row_idx \\ 0) do
    uploads =
      case Enum.find(socket.assigns.uploads, fn
             {_upload_name, %Phoenix.LiveView.UploadConfig{entries: es}} ->
               Enum.any?(es, & &1.done?)

             _other ->
               false
           end) do
        {upload_name, _cfg} ->
          try do
            socket
            |> consume_uploaded_entries(upload_name, fn %{path: path},
                                                        %Phoenix.LiveView.UploadEntry{
                                                          client_name: client
                                                        } ->
              case Phoexnip.UploadUtils.validate_file(path) do
                {:ok, valid_path} ->
                  case XlsxReader.open(valid_path, source: :path) do
                    {:ok, pkg} ->
                      sheet = Enum.at(XlsxReader.sheet_names(pkg), sheet_idx)

                      case XlsxReader.sheet(pkg, sheet) do
                        {:ok, raw} ->
                          rows = Enum.reject(raw, fn r -> Enum.all?(r, &(&1 in [nil, ""])) end)

                          unless Enum.at(rows, header_row_idx) do
                            throw({:row_oob, client})
                          end

                          header = Enum.at(rows, header_row_idx)
                          data_rows = Enum.drop(rows, header_row_idx + 1)
                          {:ok, {client, header, data_rows}}

                        {:error, msg} ->
                          throw(
                            {:file_error, client,
                             "Error reading sheet from XLSX file. Please check and re-save. Details: #{inspect(msg)}."}
                          )
                      end

                    {:error, msg} ->
                      throw(
                        {:file_error, client,
                         "Error opening XLSX file. Details: #{inspect(msg)}."}
                      )
                  end

                {:error, msg} ->
                  throw({:file_error, client, msg})
              end
            end)
          catch
            thrown_value -> thrown_value
          end

        nil ->
          []
      end

    # Handle cases
    case uploads do
      [] ->
        {:ok, {[], []}}

      {:file_error, client, msg} ->
        {:error, "Problem reading #{client}. #{msg}"}

      {:row_oob, client} ->
        {:error, "File #{client} does not have row #{header_row_idx} to use as header."}

      parsed_files when is_list(parsed_files) ->
        normalize = &(&1 |> to_string() |> String.trim() |> String.downcase())

        uniquify_headers = fn header_list ->
          {h, _} =
            Enum.map_reduce(header_list, %{}, fn h, c ->
              norm = normalize.(h)
              count = Map.get(c, norm, 0)
              new_h = if count == 0, do: norm, else: "#{norm}_#{count + 1}"
              {new_h, Map.put(c, norm, count + 1)}
            end)

          h
        end

        # Get unique headers
        processed_data =
          Enum.map(parsed_files, fn {client, header, rows} ->
            %{client: client, unique_header: uniquify_headers.(header), rows: rows}
          end)

        # Build headers
        all_unique_headers = Enum.map(processed_data, & &1.unique_header)
        unified_header = Enum.reduce(all_unique_headers, [], fn h, acc -> acc ++ (h -- acc) end)

        # Build headers lookup
        header_to_final_index = Enum.with_index(unified_header) |> Map.new()

        # Remap rows to headers
        all_reordered_rows =
          Enum.flat_map(processed_data, fn %{
                                             client: client,
                                             unique_header: file_header,
                                             rows: file_rows
                                           } ->
            remap_indices = Enum.map(file_header, &header_to_final_index[&1])

            Enum.map(file_rows, fn row ->
              new_row = List.duplicate("", Enum.count(unified_header))

              final_data =
                Enum.reduce(Enum.with_index(row), new_row, fn {cell, i}, acc ->
                  if final_idx = Enum.at(remap_indices, i),
                    do: List.replace_at(acc, final_idx, cell),
                    else: acc
                end)

              # Add filename to rows
              final_data ++ [client]
            end)
          end)

        # Add filename header
        final_header = unified_header ++ ["FILENAME"]
        {:ok, {final_header, all_reordered_rows}}
    end
  end

  @doc """
  Parses a numeric or numeric-like string input to a `DateTime` in UTC, using an Excel serial date format.

  ## Details

    * Accepts either a float or a string matching `~r/^\d+(\.\d+)?$/`.
    * If valid, it’s interpreted as an Excel serial date based on the `1900-01-01` start date.
    * Fractional parts of the input are converted to hours, minutes, and seconds.
    * Returns `{:ok, DateTime}` on success, or `nil` if the input is not valid or cannot be parsed.

  ## Examples

      iex> parse_datetime("44601.75")
      {:ok, ~U[2022-01-31 18:00:00Z]}

      iex> parse_datetime(44601.75)
      {:ok, ~U[2022-01-31 18:00:00Z]}

      iex> parse_datetime("invalid")
      nil

      iex> parse_datetime(nil)
      nil
  """
  @spec parse_datetime(input :: any()) :: {:ok, DateTime.t()} | nil

  def parse_datetime(input) do
    cond do
      # ───── nil ─────
      is_nil(input) ->
        nil

      # ───── Already DateTime ─────
      match?(%DateTime{}, input) ->
        {:ok, input}

      # ───── Already NaiveDateTime ─────
      match?(%NaiveDateTime{}, input) ->
        {:ok, Timex.to_datetime(input, "UTC")}

      # ───── Already Date ─────
      match?(%Date{}, input) ->
        {:ok, Timex.to_datetime(NaiveDateTime.new!(input, ~T[00:00:00]), "UTC")}

      # ───── Excel serial (float) ─────
      is_float(input) ->
        base = ~N[1900-01-01 00:00:00]
        days = trunc(input)
        secs = trunc((input - days) * 86_400)

        base
        |> Timex.shift(days: days - 2)
        |> Timex.shift(seconds: secs)
        |> Timex.to_datetime("UTC")
        |> then(&{:ok, &1})

      # ───── Excel serial in numeric string ─────
      is_binary(input) and String.match?(input, ~r/^\d+(\.\d+)?$/) ->
        case Float.parse(input) do
          {num, ""} -> parse_datetime(num)
          _ -> nil
        end

      # ───── ISO-8601 / RFC-3339 ─────
      is_binary(input) and match?({:ok, _, _}, DateTime.from_iso8601(input)) ->
        {:ok, elem(DateTime.from_iso8601(input), 1)}
        |> then(fn {:ok, dt} -> {:ok, DateTime.shift_zone!(dt, "UTC")} end)

      # ───── "YYYY-MM-DD HH:MM:SS" ─────
      is_binary(input) ->
        with {:ok, ndt} <- Timex.parse(input, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}") do
          {:ok, Timex.to_datetime(ndt, "UTC")}
        else
          _ -> nil
        end

      # ───── Fallback ─────
      true ->
        nil
    end
  end

  @doc """
  Ensures the given product number is returned as a string.

  ## Details

    * If the input is a number (integer or float), it truncates decimals and converts to string.
    * If the input is not numeric, returns `nil`.

  ## Examples

      iex> parse_product_number(1234)
      "1234"

      iex> parse_product_number(1234.56)
      "1234"

      iex> parse_product_number("abcd")
      nil
  """
  @spec parse_product_number(product_number :: any()) :: String.t() | nil

  def parse_product_number(product_number) do
    case product_number do
      num when is_number(num) -> trunc(num) |> Integer.to_string()
      _ -> nil
    end
  end

  @doc """
  Converts various data types into a string representation.

  ## Details

    * Floats: If the fractional part is zero, returns integer-like string (e.g. `"10"`). Otherwise, uses float string (e.g. `"10.5"`).
    * Integers: Returned as string (e.g. `123 -> "123"`).
    * Binaries: Returned as-is.
    * Lists: Joined into a comma-separated string.
    * Booleans: `true` or `false`.
    * `DateTime`: Uses `DateTime.to_string/1`.
    * Any other type or `nil`: Returns an empty string (`""`).

  ## Examples

      iex> parse_to_string(10.0)
      "10"

      iex> parse_to_string(10.5)
      "10.5"

      iex> parse_to_string([1, 2, 3])
      "1, 2, 3"

      iex> parse_to_string(~U[2022-03-01 12:00:00Z])
      "2022-03-01 12:00:00Z"

      iex> parse_to_string(nil)
      ""
  """
  @spec parse_to_string(value :: any()) :: String.t()

  def parse_to_string(value) do
    case value do
      value when is_float(value) ->
        if value == trunc(value) do
          # If decimal part is zero, truncate and convert to integer string
          value |> trunc() |> Integer.to_string()
        else
          # If decimal part exists, convert float directly to string
          Float.to_string(value)
        end

      value when is_integer(value) ->
        # Convert integer to string
        Integer.to_string(value)

      value when is_binary(value) ->
        # If it's already text, leave it as is
        value

      value when is_list(value) ->
        # Convert list to a comma-separated string
        Enum.join(value, ", ")

      value when is_boolean(value) ->
        # Convert true/false to "true"/"false"
        to_string(value)

      %DateTime{} = datetime ->
        # Convert DateTime to a string
        DateTime.to_string(datetime)

      %Date{} = date ->
        Date.to_string(date)

      _ ->
        # Default to "0" or any placeholder if the value is nil or an unknown type
        ""
    end
  end

  @doc """
  Checks whether every string in `list_a` (trimmed and downcased) appears as a substring
  in at least one string of `list_b` (also trimmed and downcased).

  ## Parameters

    * `list_a` — a list of strings to look for.
    * `list_b` — a list of candidate strings in which to search.

  ## Returns

    * `true` if for each element `a` in `list_a`, there exists some element `b` in `list_b`
      such that `a` is contained within `b` (case-insensitive, ignoring surrounding whitespace).
    * `false` otherwise.

  ## Examples

      iex> list_submatch?(["foo", "bar"], [" foOBAZ ", "quxBARqux"])
      true

      iex> list_submatch?(["baz"], ["foo", "bar"])
      false
  """
  @spec list_submatch?(
          opts :: [
            mode: String.t(),
            strict: boolean(),
            ignore_case: boolean()
          ],
          list_a :: [any()],
          list_b :: [any()]
        ) :: boolean()
  def list_submatch?(list_a, list_b, opts \\ []) do
    # Get all options at the start
    mode = Keyword.get(opts, :mode, "single")
    strict = Keyword.get(opts, :strict, false)
    ignore_case = Keyword.get(opts, :ignore_case, true)

    # Use a case statement to handle the different logic paths
    case mode do
      "pair" ->
        # Pre-process list_b once for efficiency, normalizing keys and value lists
        processed_list_b =
          Enum.map(list_b, fn {key, val_list} ->
            if ignore_case do
              norm_key = String.downcase(String.trim(key))
              norm_val_list = Enum.map(val_list, &String.downcase(String.trim(&1)))
              {norm_key, norm_val_list}
            else
              {String.trim(key), Enum.map(val_list, &String.trim(&1))}
            end
          end)

        # Check if all pairs from list_a have a corresponding match in list_b
        Enum.all?(list_a, fn {key_a, val_a} ->
          # Normalize the current element from list_a
          {norm_key_a, norm_val_a} =
            if ignore_case do
              {String.downcase(String.trim(key_a)), String.downcase(String.trim(val_a))}
            else
              {String.trim(key_a), String.trim(val_a)}
            end

          # Check if any pair in the processed list_b is a match
          Enum.any?(processed_list_b, fn {key_b, val_list_b} ->
            key_b == norm_key_a && Enum.member?(val_list_b, norm_val_a)
          end)
        end)

      # Default to "single" mode for any other value
      "single" ->
        # Pre-process list_b once for efficiency
        processed_list_b =
          if ignore_case do
            Enum.map(list_b, &String.downcase(String.trim(&1)))
          else
            Enum.map(list_b, &String.trim(&1))
          end

        # Check if all strings from list_a can be found in list_b
        Enum.all?(list_a, fn a ->
          norm_a =
            if ignore_case do
              String.downcase(String.trim(a))
            else
              String.trim(a)
            end

          # Check if any string in the processed list_b matches
          Enum.any?(processed_list_b, fn b ->
            if strict do
              b == norm_a
            else
              String.contains?(b, norm_a)
            end
          end)
        end)
    end
  end

  @doc """
  Inserts or updates multiple entities and their associations in bulk, with full recursive association support and robust conflict resolution.

  This function provides an efficient mechanism for performing upserts (insert or update) on a list of entity attribute maps for the specified `schema`. It recursively handles all associations, including nested preloads, while maintaining integrity for timestamps and supporting fine-grained control over association replacement and deletion.

  ## Parameters

    * `schema` (`module`) — The Ecto schema module representing the primary entity.
    * `entities_attrs` (`[map]`) — A list of attribute maps for entities to insert or update. Each map may contain nested association data, keyed by the association name as a string. If an entity map contains an `"id"` key, an update will be performed; otherwise, an insert is performed.
    * `chunk_size` (`integer`, optional, default: `256`) — The batch size for chunked insertion/updating of entities and their associations.
    * `on_replace` (`[atom | {atom, [atom]}]`, optional, default: `[]`) — Specifies which associations to replace (delete and re-insert) before upserting, and which nested associations to handle recursively. Supports prefixing with an underscore (`:_assoc`) to target only nested deletion without deleting the top-level association itself.

  ## Behavior

    * **Bulk Insert/Update:** For each chunk, entities are inserted or updated using `Repo.insert_all/3`, using `:replace_all` on conflict for upserts. Existing records are detected by presence of `"id"` in their attribute map.
    * **Association Recursion:** After top-level entity upserts, the function recursively processes all associations using chunked upserts, ensuring nested associations are also updated or inserted as needed.
    * **Timestamps:** Both `:inserted_at` and `:updated_at` fields are handled intelligently. If present in the original attribute map, these values are respected; otherwise, the current transaction timestamp is used.
    * **Association Replacement:** Associations named in `on_replace` are deleted before the corresponding parent entity is upserted. Nested deletes can be specified for fine-grained cleanup of child associations, with subquery safety for batch deletes.
    * **Transaction:** All operations occur within a single transaction, ensuring atomicity.
    * **Return Value:** Returns a map containing:
      - `:updated_entities` — List of fully preloaded, upserted entities.
      - `:original_entities` — Map of previously existing entities keyed by id, only for those updated in this operation.

  ## Examples

      iex> bulk_upsert(Product, [%{"name" => "Widget", "variants" => [%{"sku" => "ABC123"}]}])
      %{updated_entities: [%Product{...}], original_entities: %{}}

      iex> bulk_upsert(Order, [%{"id" => 5, "status" => "shipped"}], 100, on_replace: [:line_items])
      %{updated_entities: [%Order{...}], original_entities: %{5 => %Order{...}}}

  ## Options

    * Handles both inserts and updates in a single operation.
    * Supports arbitrarily nested associations and multi-level deletes.
    * Association replacement/deletion logic is customizable per-association and per-nesting.
    * Returns all resulting entities with all associations preloaded.

  ## Returns

    * `%{updated_entities: [struct()], original_entities: %{integer() => struct()}}`

  """
  @spec bulk_upsert(
          schema :: module(),
          entities_attrs :: [map()],
          chunk_size :: non_neg_integer(),
          on_replace :: atom() | {atom(), [atom()]} | [atom() | {atom(), [atom()]}]
        ) ::
          {:ok,
           %{
             updated_entities: [struct()],
             original_entities: %{optional(any()) => struct()}
           }}
          | {:error, term()}

  def bulk_upsert(schema, entities_attrs, chunk_size \\ 256, on_replace \\ [])
      when is_list(entities_attrs) do
    # Helper function to check if value is NotLoaded
    is_not_loaded = fn value -> match?(%Ecto.Association.NotLoaded{}, value) end

    on_replace =
      on_replace
      |> List.wrap()
      |> Enum.map(fn
        a when is_atom(a) ->
          {a, []}

        {a, nested} when is_atom(a) and is_list(nested) ->
          if Enum.all?(nested, &is_atom/1) do
            {a, nested}
          else
            raise ArgumentError,
                  "on_replace nested list must contain only atoms; got: #{inspect(nested)}"
          end

        bad ->
          raise ArgumentError,
                "on_replace must be an atom, a {atom, [atom()]} tuple, or a list of those; got: #{inspect(bad)}"
      end)

    Repo.transaction(
      fn ->
        timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

        # Helper to build a nested preload query for all associations of a given schema.
        preload_all = fn rec_fun, current_schema, visited ->
          if MapSet.member?(visited, current_schema) do
            []
          else
            new_visited = MapSet.put(visited, current_schema)

            current_schema.__schema__(:associations)
            |> Enum.map(fn assoc ->
              assoc_info = current_schema.__schema__(:association, assoc)
              related_schema = assoc_info.queryable
              nested_preloads = rec_fun.(rec_fun, related_schema, new_visited)
              if nested_preloads == [], do: assoc, else: {assoc, nested_preloads}
            end)
          end
        end

        add_timestamps = fn processed_data, original_attrs, schema, timestamp, original_entity ->
          schema_fields = schema.__schema__(:fields)

          processed_data
          |> then(fn current_data ->
            if :inserted_at in schema_fields do
              inserted_at_value =
                case original_entity do
                  nil -> Map.get(original_attrs, "inserted_at", timestamp)
                  entity -> entity.inserted_at
                end

              Map.put(current_data, :inserted_at, inserted_at_value)
            else
              current_data
            end
          end)
          |> then(fn current_data ->
            if :updated_at in schema_fields do
              updated_at_value = Map.get(original_attrs, "updated_at", timestamp)
              Map.put(current_data, :updated_at, updated_at_value)
            else
              current_data
            end
          end)
        end

        # STEP 1: Identify ALL entities that are updates by the presence of an "id".
        ids_for_update =
          entities_attrs
          |> Enum.filter(&Map.has_key?(&1, "id"))
          |> Enum.map(&Map.get(&1, "id"))

        # STEP 2: Fetch the original state of ALL entities being updated.
        original_entities =
          if ids_for_update != [] do
            from(s in schema, where: s.id in ^ids_for_update)
            |> Repo.all()
            |> Repo.preload(preload_all.(preload_all, schema, MapSet.new()))
            |> Enum.into(%{}, &{&1.id, &1})
          else
            %{}
          end

        # STEP 3: Apply on_replace deletes if requested.
        if on_replace != [] and ids_for_update != [] do
          Enum.each(on_replace, fn {assoc_name, nested_assocs} ->
            assoc_name_str = Atom.to_string(assoc_name)

            if String.starts_with?(assoc_name_str, "_") do
              real_assoc_name = String.to_existing_atom(String.trim_leading(assoc_name_str, "_"))
              real_assoc_info = schema.__schema__(:association, real_assoc_name)

              assoc_ids_query =
                from(a in real_assoc_info.queryable,
                  where: field(a, ^real_assoc_info.related_key) in ^ids_for_update,
                  select: a.id
                )

              Enum.each(nested_assocs, fn nested_assoc ->
                nested_info = real_assoc_info.queryable.__schema__(:association, nested_assoc)

                from(na in nested_info.queryable,
                  where: field(na, ^nested_info.related_key) in subquery(assoc_ids_query)
                )
                |> Repo.delete_all()
              end)
            else
              # Regular deletion - delete nested first, then parent
              assoc_info = schema.__schema__(:association, assoc_name)

              assoc_ids_query =
                from(a in assoc_info.queryable,
                  where: field(a, ^assoc_info.related_key) in ^ids_for_update,
                  select: a.id
                )

              Enum.each(nested_assocs, fn nested_assoc ->
                nested_info = assoc_info.queryable.__schema__(:association, nested_assoc)

                from(na in nested_info.queryable,
                  where: field(na, ^nested_info.related_key) in subquery(assoc_ids_query)
                )
                |> Repo.delete_all()
              end)

              from(a in assoc_info.queryable,
                where: field(a, ^assoc_info.related_key) in ^ids_for_update
              )
              |> Repo.delete_all()
            end
          end)
        end

        # STEP 4: Process and upsert entities in chunks.
        entities =
          entities_attrs
          |> Stream.chunk_every(chunk_size)
          |> Enum.reduce([], fn chunk, acc_entities ->
            {_count, entities_in_chunk} =
              chunk
              |> Enum.map(fn attrs ->
                # Filter out NotLoaded associations first, then process normally
                cleaned_attrs =
                  attrs
                  |> Enum.filter(fn {_k, v} -> not is_not_loaded.(v) end)
                  |> Enum.into(%{})

                processed =
                  cleaned_attrs
                  |> Map.drop(schema.__schema__(:associations) |> Enum.map(&Atom.to_string/1))
                  |> Map.new(fn {k, v} ->
                    key_atom = if is_atom(k), do: k, else: String.to_existing_atom(k)
                    {key_atom, SearchUtils.convert_value_to_field(schema, key_atom, v)}
                  end)
                  |> Map.take(schema.__schema__(:fields))

                original_entity =
                  if Map.has_key?(attrs, "id"), do: original_entities[attrs["id"]], else: nil

                add_timestamps.(processed, cleaned_attrs, schema, timestamp, original_entity)
              end)
              |> (&Repo.insert_all(schema, &1,
                    returning: true,
                    on_conflict: :replace_all,
                    conflict_target: schema.__schema__(:primary_key),
                    timeout: :infinity
                  )).()

            # STEP 5: Recursively process associations for the entities in this chunk.
            recursive_processor = fn me, parent_schema, entity_attr_pairs ->
              parent_schema.__schema__(:associations)
              |> Enum.each(fn assoc ->
                assoc_info = parent_schema.__schema__(:association, assoc)
                assoc_schema = assoc_info.queryable
                assoc_str = Atom.to_string(assoc)

                assoc_entries_with_data =
                  entity_attr_pairs
                  |> Enum.flat_map(fn {parent_entity, parent_attrs} ->
                    assoc_data = Map.get(parent_attrs, assoc_str)

                    # Skip if the association is NotLoaded
                    if is_not_loaded.(assoc_data) do
                      []
                    else
                      assoc_attrs_list =
                        case assoc_info.cardinality do
                          :one ->
                            if is_map(assoc_data), do: [assoc_data], else: []

                          :many ->
                            cond do
                              is_map(assoc_data) -> Map.values(assoc_data)
                              is_list(assoc_data) -> assoc_data
                              true -> []
                            end
                            |> Enum.filter(&is_map/1)
                        end

                      Enum.map(assoc_attrs_list, &{&1, parent_entity.id})
                    end
                  end)

                if assoc_entries_with_data != [] do
                  processed_data =
                    Enum.map(assoc_entries_with_data, fn {attrs, parent_id} ->
                      # Also clean NotLoaded from nested associations
                      cleaned_nested_attrs =
                        attrs
                        |> Enum.filter(fn {_k, v} -> not is_not_loaded.(v) end)
                        |> Enum.into(%{})

                      nested_assoc_keys =
                        assoc_schema.__schema__(:associations) |> Enum.map(&Atom.to_string/1)

                      processed =
                        cleaned_nested_attrs
                        |> Map.drop(nested_assoc_keys)
                        |> Map.new(fn {k, v} ->
                          key_atom = if is_atom(k), do: k, else: String.to_existing_atom(k)

                          {key_atom,
                           SearchUtils.convert_value_to_field(assoc_schema, key_atom, v)}
                        end)
                        |> Map.put(assoc_info.related_key, parent_id)
                        |> Map.take(assoc_schema.__schema__(:fields))

                      original_parent = Map.get(original_entities, parent_id)

                      original_assoc =
                        if Map.has_key?(attrs, "id") and original_parent do
                          case assoc_info.cardinality do
                            :one ->
                              Map.get(original_parent, assoc)
                              |> then(&if(&1 && &1.id == attrs["id"], do: &1, else: nil))

                            :many ->
                              Map.get(original_parent, assoc, [])
                              |> Enum.find(&(&1 && &1.id == attrs["id"]))
                          end
                        end

                      processed =
                        add_timestamps.(
                          processed,
                          cleaned_nested_attrs,
                          assoc_schema,
                          timestamp,
                          original_assoc
                        )

                      {processed, cleaned_nested_attrs}
                    end)

                  entries_to_insert = Enum.map(processed_data, &elem(&1, 0))

                  {_sub_count, inserted_assocs} =
                    entries_to_insert
                    |> Stream.chunk_every(chunk_size)
                    |> Enum.reduce({0, []}, fn inner_chunk, {acc_count, acc_assocs} ->
                      {sub_count, returned} =
                        Repo.insert_all(assoc_schema, inner_chunk,
                          returning: true,
                          on_conflict: :replace_all,
                          conflict_target: assoc_schema.__schema__(:primary_key),
                          timeout: :infinity
                        )

                      {acc_count + sub_count, acc_assocs ++ returned}
                    end)

                  if inserted_assocs != [] do
                    original_data_for_next_level = Enum.map(processed_data, &elem(&1, 1))
                    me.(me, assoc_schema, Enum.zip(inserted_assocs, original_data_for_next_level))
                  end
                end
              end)
            end

            # Clean the chunk data before passing to recursive processor
            cleaned_chunk =
              chunk
              |> Enum.map(fn attrs ->
                attrs
                |> Enum.filter(fn {_k, v} -> not is_not_loaded.(v) end)
                |> Enum.into(%{})
              end)

            recursive_processor.(
              recursive_processor,
              schema,
              Enum.zip(entities_in_chunk, cleaned_chunk)
            )

            acc_entities ++ entities_in_chunk
          end)

        # STEP 6: Preload all data for the final, clean return value.
        reloaded_entities =
          Repo.preload(entities, preload_all.(preload_all, schema, MapSet.new()))

        %{updated_entities: reloaded_entities, original_entities: original_entities}
      end,
      timeout: :infinity,
      ownership_timeout: :infinity
    )
  end

  @doc """
  Recursively generates a list of associations for preloading from the given Ecto schema,
  excluding `belongs_to` associations, and optionally applying `order_by` on any child.

  ## Parameters
    - `schema`  - An Ecto schema module.
    - `visited` - A MapSet of schemas already seen (to avoid cycles).
    - `opts`    - A map of association names to order-by clauses, e.g.
                  `%{productsupplier: [asc: :sequence], costingtrim: [desc: :id]}`

  ## Returns
    - A list of preloads, where each preload is either:
      - an atom `:assoc`
      - `{assoc, nested}` if you only need nested preloads
      - `{assoc, queryable}` if you only need ordering
      - `{assoc, {queryable, nested}}` if you need both
  """
  @spec preload_all(
          schema :: module(),
          opts :: %{optional(atom()) => any()},
          visited :: MapSet.t(module())
        ) :: [atom() | {atom(), any()}]

  def preload_all(schema, opts \\ %{}, visited \\ MapSet.new()) do
    if MapSet.member?(visited, schema) do
      []
    else
      new_visited = MapSet.put(visited, schema)

      schema.__schema__(:associations)
      |> Enum.filter(fn assoc ->
        case schema.__schema__(:association, assoc) do
          %Ecto.Association.BelongsTo{} -> false
          _ -> true
        end
      end)
      |> Enum.map(fn assoc ->
        assoc_info = schema.__schema__(:association, assoc)
        nested_preloads = preload_all(assoc_info.queryable, opts, new_visited)

        # Check if there's a passed in options for this association
        case Map.get(opts, assoc) do
          nil ->
            # No options, use default behavior
            if nested_preloads == [] do
              assoc
            else
              {assoc, nested_preloads}
            end

          options ->
            # Use passed in options, but still include nested preloads if they exist
            if nested_preloads == [] do
              {assoc, options}
            else
              {assoc, {options, nested_preloads}}
            end
        end
      end)
    end
  end

  @doc """
  Transforms search result entries into a form-friendly structure.

  This function converts SearchUtils.search() results—whether they are single structs, lists of structs, or nested
  associations—into a map with string keys, making the data more suitable for use in forms.
  It handles lists by converting them to maps with stringified indices and processes nested associations
  recursively. If an association is not loaded, it returns `nil`.

  ## Parameters
    - `entries` - The search result entry or entries to transform. This can be a list, a struct,
      or another data type.
    - `schema` - The Ecto schema (or a tuple of the schema and its association names) used
      to identify and process associations.

  ## Returns
    - A transformed data structure:
        - Lists are converted to maps with keys as stringified indices.
        - Structs are converted to maps with string keys, excluding the `__meta__` field.
        - Unloaded Ecto associations yield `nil`.
        - Nested associations are processed recursively.
  """
  @spec transform_search_to_form_struct(
          entries :: any(),
          schema :: module() | {module(), MapSet.t(String.t())} | nil
        ) :: any()

  def transform_search_to_form_struct(entries, schema \\ nil) do
    cond do
      is_nil(schema) and is_list(entries) ->
        Enum.map(entries, fn entry ->
          entry
          |> Map.from_struct()
          |> Map.delete(:__meta__)
          |> Enum.into(%{}, fn {key, value} ->
            {Atom.to_string(key), value}
          end)
        end)

      is_nil(schema) ->
        entries

      is_list(entries) and is_atom(schema) ->
        assoc_names =
          schema.__schema__(:associations)
          |> Enum.map(&Atom.to_string/1)
          |> MapSet.new()

        Enum.map(entries, &transform_search_to_form_struct(&1, {schema, assoc_names}))

      is_list(entries) ->
        entries
        |> Enum.with_index()
        |> Enum.into(%{}, fn {item, idx} ->
          {"#{idx}", transform_search_to_form_struct(item, schema)}
        end)

      is_struct(entries, Ecto.Association.NotLoaded) ->
        nil

      is_struct(entries) ->
        {schema_mod, assoc_names} =
          case schema do
            {schema_mod, assoc} -> {schema_mod, assoc}
            _ -> {nil, MapSet.new()}
          end

        if is_nil(schema_mod) do
          Map.from_struct(entries) |> Map.delete(:__meta__)
        else
          entries
          |> Map.from_struct()
          |> Map.delete(:__meta__)
          |> Enum.into(%{}, fn {key, value} ->
            key_str = Atom.to_string(key)

            if MapSet.member?(assoc_names, key_str) && value != nil do
              assoc_schema =
                schema_mod.__schema__(:association, String.to_existing_atom(key_str)).queryable

              assoc_names_nested =
                assoc_schema.__schema__(:associations)
                |> Enum.map(&Atom.to_string/1)
                |> MapSet.new()

              {key_str,
               transform_search_to_form_struct(value, {assoc_schema, assoc_names_nested})}
            else
              {key_str, value}
            end
          end)
        end

      true ->
        entries
    end
  end

  @doc """
  Enumerates header values from a row based on header names or groups.

  ## Parameters

    * `row` — a list of cell values.
    * `headers` — a list of header strings corresponding to columns in `row`.
    * `header_names` — a list where each element is either:
      - a string header name to look for, or
      - a list of string alternatives. For lists, the function picks the first matching header.

  For each element in `header_names`, the function:
    1. If it’s a list of strings, finds the first header in `headers` (case-insensitive, trimmed) matching any of those, and returns the corresponding `row` value.
    2. If it’s a string, finds its index in `headers` (case-insensitive, trimmed) and returns the corresponding `row` value.
    3. If no match is found, returns an empty string `""`.

  ## Returns

    * A list of values from `row`, in the same order as `header_names`, defaulting to `""` when no header match is found.
  """
  @spec enum_header(
          row :: [any()],
          headers :: [String.t()],
          header_names :: [String.t() | [String.t()]]
        ) :: [any()]
  def enum_header(row, headers, header_names) do
    header_names
    |> Enum.map(fn header_group ->
      case header_group do
        # If it's a list, check each option until one is found
        list when is_list(list) ->
          list
          |> Enum.find_value(fn header ->
            index =
              Enum.find_index(headers, fn h ->
                String.trim(h) |> String.downcase() ==
                  String.trim(header) |> String.downcase()
              end)

            if not is_nil(index), do: Enum.at(row, index, ""), else: nil
          end) || ""

        # If it's a single string, treat it as usual
        header when is_binary(header) ->
          index =
            Enum.find_index(headers, fn h ->
              String.trim(h) |> String.downcase() ==
                String.trim(header) |> String.downcase()
            end)

          if not is_nil(index), do: Enum.at(row, index, ""), else: ""
      end
    end)
  end
end
