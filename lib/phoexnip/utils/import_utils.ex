defmodule Phoexnip.ImportUtils do
  @moduledoc """
  Utilities for importing and transforming data from external sources.

  This module provides a suite of functions to:

    * `parse_datetime/1` — Convert various inputs (Excel serial dates, ISO‑8601 strings, NaiveDateTime, Date)
      into a UTC `DateTime`; returns `{:ok, datetime}` or `nil`.
    * `parse_date!/1` — Convert supported inputs into a `Date`, returning `nil` on failure.
    * `parse_to_string/1` — Render floats, integers, binaries, lists, booleans, `DateTime`/`Date` into string form.
    * `preload_all/3` — Recursively generate Ecto preload specifications (excluding `belongs_to`),
      with optional ordering per association.
    * `reset_upload/2` — Clear all entries from a LiveView upload config.

  ## Examples

      iex> ImportUtils.parse_datetime("44601.75")
      {:ok, ~U[2022-01-31 18:00:00Z]}

  """

  import Phoenix.LiveView.Upload

  @doc """
  Parses a numeric or numeric-like string input to a `DateTime` in UTC, using an Excel serial date format.

  ## Details

    * Accepts either a float or a string matching `~r/^\d+(\.\d+)?$/`.
    * If valid, it's interpreted as an Excel serial date based on the `1900-01-01` start date.
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
  @spec parse_datetime(input :: any()) :: {:ok, DateTime.t()} | {:ok, nil}

  def parse_datetime(input) do
    cond do
      # ───── nil ─────
      is_nil(input) ->
        {:ok, nil}

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

      # ───── Valid Binary ─────
      is_binary(input) ->
        formats_to_try = [
          "{YYYY}-{0M}-{0D} {h24}:{m}:{s}",
          "{YYYY}-{0M}-{0D}T{h24}:{m}",
          "{0D}/{0M}/{YYYY} {h24}:{m}:{s}",
          "{YYYY}/{0M}/{0D} {h24}:{m}:{s}",
          "{0D}-{0M}-{YYYY} {h24}:{m}:{s}",
          "{0D}/{0M}/{YYYY}",
          "{YYYY}/{0M}/{0D}",
          "{YYYY}-{0M}-{0D}",
          "{0D}-{0M}-{YYYY}"
        ]

        Enum.find_value(formats_to_try, fn format ->
          case Timex.parse(input, format) do
            {:ok, ndt} ->
              {:ok, Timex.to_datetime(ndt, "UTC")}

            _ ->
              nil
          end
        end) || {:ok, nil}

      # ───── Fallback ─────
      true ->
        {:ok, nil}
    end
  end

  @spec parse_date(input :: any()) :: {:ok, Date.t() | nil}
  defp parse_date(input) do
    cond do
      is_nil(input) ->
        {:ok, nil}

      match?(%Date{}, input) ->
        {:ok, input}

      match?(%DateTime{}, input) ->
        {:ok, DateTime.to_date(input)}

      match?(%NaiveDateTime{}, input) ->
        {:ok, NaiveDateTime.to_date(input)}

      true ->
        case parse_datetime(input) do
          {:ok, nil} -> {:ok, nil}
          {:ok, dt} -> {:ok, DateTime.to_date(dt)}
        end
    end
  end

  @doc """
  Bang variant of `parse_date/1` that unwraps the `{:ok, date}` tuple.

  ## Examples

      iex> parse_date!("44601.75")
      ~D[2022-01-31]

      iex> parse_date!(nil)
      nil
  """
  @spec parse_date!(input :: any()) :: Date.t() | nil
  def parse_date!(input) do
    {:ok, d} = parse_date(input)
    d
  end

  @doc """
  Converts various data types into a float representation.

  ## Details

    * Floats: Returned as-is.
    * Integers: Converted to float (e.g. `123 -> 123.0`).
    * Binaries: Parsed as float if valid, otherwise returns `0.0`.
    * Lists: If single numeric element, converts that element. Otherwise returns `0.0`.
    * Booleans: `true` becomes `1.0`, `false` becomes `0.0`.
    * `DateTime`: Returns Unix timestamp as float.
    * `Date`: Returns days since Unix epoch as float.
    * Any other type or `nil`: Returns `0.0`.

  ## Examples

      iex> parse_to_float(10)
      10.0

      iex> parse_to_float("10.5")
      10.5

      iex> parse_to_float("invalid")
      0.0

      iex> parse_to_float([42])
      42.0

      iex> parse_to_float(true)
      1.0

      iex> parse_to_float(nil)
      0.0
  """
  @spec parse_to_float(value :: any()) :: float()

  def parse_to_float(value) do
    case value do
      value when is_float(value) ->
        value

      value when is_integer(value) ->
        value / 1

      value when is_binary(value) ->
        case Float.parse(String.trim(value)) do
          {float_val, _} -> float_val
          :error -> 0.0
        end

      value when is_list(value) ->
        case value do
          [single_value] -> parse_to_float(single_value)
          _ -> 0.0
        end

      value when is_boolean(value) ->
        if value, do: 1.0, else: 0.0

      %DateTime{} = datetime ->
        datetime |> DateTime.to_unix() |> parse_to_float()

      %Decimal{} = decimal ->
        Decimal.to_float(decimal)

      %Date{} = date ->
        date |> Date.to_erl() |> :calendar.date_to_gregorian_days() |> parse_to_float()

      _ ->
        0.0
    end
  end

  @doc """
  Converts various data types into an integer representation.

  ## Details

    * Integers: Returned as-is.
    * Floats: Truncated to integer (e.g. `10.9 -> 10`).
    * Binaries: Parsed as integer if valid, otherwise returns `0`.
    * Lists: If single numeric element, converts that element. Otherwise returns `0`.
    * Booleans: `true` becomes `1`, `false` becomes `0`.
    * `DateTime`: Returns Unix timestamp as integer.
    * `Date`: Returns days since Unix epoch as integer.
    * Any other type or `nil`: Returns `0`.

  ## Examples

      iex> parse_to_integer(10.9)
      10

      iex> parse_to_integer("123")
      123

      iex> parse_to_integer("invalid")
      0

      iex> parse_to_integer([42.5])
      42

      iex> parse_to_integer(false)
      0

      iex> parse_to_integer(nil)
      0
  """
  @spec parse_to_integer(value :: any()) :: integer()

  def parse_to_integer(value) do
    case value do
      value when is_integer(value) ->
        value

      value when is_float(value) ->
        round(value)

      value when is_binary(value) ->
        trimmed = String.trim(value)

        if String.contains?(trimmed, ".") do
          case Float.parse(trimmed) do
            {float_val, _} -> round(float_val)
            :error -> 0
          end
        else
          case Integer.parse(trimmed) do
            {int_val, _} -> int_val
            :error -> 0
          end
        end

      value when is_list(value) ->
        case value do
          [single_value] -> parse_to_integer(single_value)
          _ -> 0
        end

      value when is_boolean(value) ->
        if value, do: 1, else: 0

      %Decimal{} = decimal ->
        decimal |> Decimal.round(0) |> Decimal.to_integer()

      %DateTime{} = datetime ->
        DateTime.to_unix(datetime)

      %Date{} = date ->
        date |> Date.to_erl() |> :calendar.date_to_gregorian_days()

      _ ->
        0
    end
  end

  @doc """
  Converts various data types into a `Decimal` struct.

  ## Details

    * Decimals: Returned as-is.
    * Integers: Converted via `Decimal.new/1`.
    * Floats: Converted via `Decimal.from_float/1`.
    * Strings: Parsed via `Decimal.parse/1`, returns `Decimal.new(0)` on failure.
    * Booleans: `true` becomes `Decimal.new(1)`, `false` becomes `Decimal.new(0)`.
    * Lists: If single element, converts that element. Otherwise returns `Decimal.new(0)`.
    * DateTime: Returns Unix timestamp as Decimal.
    * Date: Returns gregorian days as Decimal.
    * Any other type or `nil`: Returns `Decimal.new(0)`.

  ## Examples

      iex> parse_to_decimal("10.5")
      #Decimal<10.5>

      iex> parse_to_decimal(true)
      #Decimal<1>

      iex> parse_to_decimal(nil)
      #Decimal<0>
  """
  @spec parse_to_decimal(value :: any()) :: Decimal.t()
  def parse_to_decimal(value) do
    case value do
      %Decimal{} = decimal ->
        decimal

      value when is_integer(value) ->
        Decimal.new(value)

      value when is_float(value) ->
        Decimal.from_float(value)

      value when is_binary(value) ->
        case Decimal.parse(String.trim(value)) do
          {decimal, _} -> decimal
          :error -> Decimal.new(0)
        end

      value when is_list(value) ->
        case value do
          [single_value] -> parse_to_decimal(single_value)
          _ -> Decimal.new(0)
        end

      value when is_boolean(value) ->
        if value, do: Decimal.new(1), else: Decimal.new(0)

      %DateTime{} = datetime ->
        datetime |> DateTime.to_unix() |> Decimal.new()

      %Date{} = date ->
        date |> Date.to_erl() |> :calendar.date_to_gregorian_days() |> Decimal.new()

      _ ->
        Decimal.new(0)
    end
  end

  @doc """
  Converts various data types into a boolean.

  ## Details

    * Booleans: Returned as-is.
    * Strings: `"true"`, `"1"`, `"yes"` → `true`; `"false"`, `"0"`, `"no"` → `false` (case-insensitive, trimmed).
    * Integers: `1` → `true`, `0` → `false`.
    * `nil` or unrecognized: Returns `nil`.

  ## Examples

      iex> parse_to_boolean("true")
      true

      iex> parse_to_boolean("NO")
      false

      iex> parse_to_boolean(1)
      true

      iex> parse_to_boolean(nil)
      nil
  """
  @spec parse_to_boolean(value :: any()) :: boolean() | nil
  def parse_to_boolean(value) do
    case value do
      value when is_boolean(value) ->
        value

      value when is_binary(value) ->
        case String.downcase(String.trim(value)) do
          v when v in ["true", "1", "yes"] -> true
          v when v in ["false", "0", "no"] -> false
          _ -> nil
        end

      value when is_integer(value) ->
        value != 0

      _ ->
        nil
    end
  end

  @doc """
  Parses various inputs into a `Time` struct.

  ## Details

    * `%Time{}`: Returned as-is.
    * Strings: Parsed via `Time.from_iso8601/1`.
    * `%DateTime{}`: Extracts time via `DateTime.to_time/1`.
    * `%NaiveDateTime{}`: Extracts time via `NaiveDateTime.to_time/1`.
    * `nil` or unrecognized: Returns `nil`.

  ## Examples

      iex> parse_to_time("12:30:00")
      ~T[12:30:00]

      iex> parse_to_time(~T[08:00:00])
      ~T[08:00:00]

      iex> parse_to_time(nil)
      nil
  """
  @spec parse_to_time(value :: any()) :: Time.t() | nil
  def parse_to_time(value) do
    case value do
      %Time{} = time ->
        time

      value when is_binary(value) ->
        case Time.from_iso8601(String.trim(value)) do
          {:ok, t} -> t
          _ -> nil
        end

      %DateTime{} = dt ->
        DateTime.to_time(dt)

      %NaiveDateTime{} = ndt ->
        NaiveDateTime.to_time(ndt)

      _ ->
        nil
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
    value =
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
          to_string(value)

        %Decimal{} = decimal ->
          Decimal.to_string(decimal)

        %DateTime{} = datetime ->
          DateTime.to_string(datetime)

        %Date{} = date ->
          Date.to_string(date)

        _ ->
          # Default to "0" or any placeholder if the value is nil or an unknown type
          ""
      end

    value |> String.trim()
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
  Resets all entries for a given upload in a LiveView socket.

  Every entry for `upload_name` is cancelled, regardless of its current state.
  If `upload_name` is not present in `socket.assigns.uploads`, the function is a no-op.

  ## Parameters
    - `socket` - The LiveView socket that contains upload configuration(s).
    - `upload_name` - The upload name configured via `allow_upload/3`.

  ## Returns
    - The updated socket after cancelling all entries for the upload.
  """
  @spec reset_upload(socket :: Phoenix.LiveView.Socket.t(), upload_name :: atom()) ::
          Phoenix.LiveView.Socket.t()
  def reset_upload(socket, upload_name) do
    # Check if upload entries for this config exists
    if upload_config = socket.assigns.uploads[upload_name] do
      # For every single entry, regardless of its state (done, progress, error),
      # simply cancel it. This is the most direct way to clear the entries list.
      Enum.reduce(upload_config.entries, socket, fn entry, acc_socket ->
        cancel_upload(acc_socket, upload_name, entry.ref)
      end)
    else
      # The upload config for this name didn't exist, so do nothing.
      socket
    end
  end
end
