defmodule Phoexnip.OrderNumberUtils do
  @moduledoc """
  Utilities for generating and formatting sequential order or transaction numbers
  backed by database-side counters, with support for Timex-based date placeholders,
  zero-padding, and optional suffixes.

  This module provides:

    * `get_next_running_number/2` – Atomically increment and fetch the next value via
      a stored procedure (`update_and_get_value`), then format with prefix, zero‑pad,
      and suffix. Returns `{:ok, formatted}` or `{:error, reason}`.
    * `get_next_running_number!/2` – Same as `get_next_running_number/2` but raises on error.
    * `look_at_next_running_number/2` – Read & increment a counter stored in the
      `"transactionkeys"` table, without a stored procedure. Returns `{:ok, formatted}`
      or `{:error, reason}`.
    * `look_at_next_running_number!/2` – Same as `look_at_next_running_number/2` but raises.
    * `generate_running_number/4` – Given a prefix, integer, zero‑padding width, and
      suffix, return a string like `"PREFIX-0001-SFX"`.
    * `format_with_timex/1` – Inject current date/time values into a template string
      containing `{<Timex format>}` placeholders.

  ## Options

    * `:suffix`   – `String.t()` to append after the numeric part (default `""`).
    * `:zero_pad` – `non_neg_integer()` minimum width for the numeric part (default `4`).

  ## Examples

      iex> get_next_running_number("ORD")
      {:ok, "ORD-0001"}

      iex> look_at_next_running_number("{YYYYMM}", suffix: "US")
      {:ok, "20250724-0001-US"}

      iex> generate_running_number("INV", 42, 6, "EU")
      "INV-000042-EU"
  """
  alias Timex
  alias Phoexnip.Repo

  @doc """
  Invoke a database‐side stored procedure to atomically increment and retrieve the next running number
  for a composite key, then format that number with the given prefix/suffix and zero‐padding.

  This function will:

    1. Render any Timex format directives in `prefix` and optional `:suffix` via `format_with_timex/1`.
    2. Concatenate the formatted prefix and suffix into a single lookup key.
    3. Call the SQL function `update_and_get_value(key)` (via Ecto fragment) to increment & return the next integer.
    4. If the call returns an integer, format it with `generate_running_number/4`.
    5. Return `{:ok, formatted_string}` on success.
    6. Return `{:error, :no_result}` if the SQL returns `nil`, or `{:error, {:unexpected_result, result}}`
       for any non‐integer response. Any exceptions are caught and returned as `{:error, reason}`.

  ## Options

    * `:suffix`   — `String.t()` to append after the numeric part (default `""`).
    * `:zero_pad` — `non_neg_integer()` minimum width of the numeric part (default `4`).

  ## Examples

      iex> get_next_running_number("ORD")
      {:ok, "ORD-0001"}            # if the SQL function starts at 1

      iex> get_next_running_number("INV", suffix: "EU")
      {:ok, "INV-0002-EU"}         # if current value was 1

      iex> get_next_running_number("TCKT", zero_pad: 6)
      {:ok, "TCKT-000003"}         # if current value was 2

      iex> get_next_running_number("BAD")
      {:error, :no_result}         # if the fragment returns nil

      iex> get_next_running_number("WEIRD")
      {:error, {:unexpected_result, "foo"}}  # if the SQL returned a non‐integer
  """
  @spec get_next_running_number(
          prefix :: String.t(),
          opts :: [suffix: String.t(), zero_pad: non_neg_integer()]
        ) :: {:ok, String.t()} | {:error, any()}
  def get_next_running_number(prefix, opts \\ []) do
    # render any Timex‐style formats in prefix & suffix
    prefix = format_with_timex(prefix)
    suffix = format_with_timex(Keyword.get(opts, :suffix, ""))
    zero_pad = Keyword.get(opts, :zero_pad, 4)

    # build the composite key and SQL fragment query
    db_lookup_key = prefix <> suffix
    import Ecto.Query, only: [from: 2]

    query =
      from r in fragment("SELECT update_and_get_value(?) AS value", ^db_lookup_key),
        select: r.value

    try do
      case Repo.one(query) do
        nil ->
          {:error, :no_result}

        value when is_integer(value) ->
          formatted = generate_running_number(prefix, value, zero_pad, suffix)
          {:ok, formatted}

        other ->
          {:error, {:unexpected_result, other}}
      end
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Same as `get_next_running_number/2`, but raises on any error instead of returning `{:error, reason}`.

  Returns the formatted running string directly, or raises a `RuntimeError` on failure.

  ## Examples

  iex> get_next_running_number!("ORD")
  "ORD-0001"

  iex> get_next_running_number!("INV", suffix: "APAC")
  "INV-0005-APAC"

  iex> get_next_running_number!("BAD")
  ** (RuntimeError) Failed to get next running number: :no_result
  """
  @spec get_next_running_number!(
          prefix :: String.t(),
          opts :: [suffix: String.t(), zero_pad: non_neg_integer()]
        ) :: String.t()
  def get_next_running_number!(prefix, opts \\ []) do
    case get_next_running_number(prefix, opts) do
      {:ok, str} ->
        str

      {:error, reason} ->
        raise "Failed to get next running number: #{inspect(reason)}"
    end
  end

  @doc """
  Look up and format the next running number for a given key composed of a prefix and optional suffix.

  This function will:

    1. Render any Timex format directives in `prefix` and `:suffix` (via `format_with_timex/1`).
    2. Concatenate the formatted prefix and suffix into a database key.
    3. Query the `"transactionkeys"` table for the current integer value stored under that key.
    4. If no entry exists, start at `1`; otherwise increment the stored integer by `1`.
    5. Generate the formatted identifier using `generate_running_number/4`.
    6. Return `{:ok, formatted_identifier}` on success, or `{:error, reason}` if any exception occurs.

  ## Options

    * `:suffix`   — `String.t()` to append after the number (default `""`).
    * `:zero_pad` — `non_neg_integer()` minimum width for the running number (default `4`).

  ## Returns

    * `{:ok, String.t()}` on success.
    * `{:error, any()}` if an exception is raised during lookup or formatting.

  ## Examples

      iex> look_at_next_running_number("ORD-{YYYY}", suffix: "US")
      {:ok, "ORD-2025-07-18-0001-US"}     # if no DB entry yet

      iex> look_at_next_running_number("ORD", zero_pad: 5)
      {:ok, "ORD-00002"}                  # if DB entry was 1

      iex> look_at_next_running_number("INV", suffix: "EU", zero_pad: 3)
      {:ok, "INV-025-EU"}                  # if DB entry was 24
  """
  @spec look_at_next_running_number(
          prefix :: String.t(),
          opts :: [suffix: String.t(), zero_pad: non_neg_integer()]
        ) :: {:ok, String.t()} | {:error, any()}
  def look_at_next_running_number(prefix, opts \\ []) do
    # first parse any formatting in prefix or suffix
    prefix = format_with_timex(prefix)
    suffix = format_with_timex(Keyword.get(opts, :suffix, ""))
    zero_pad = Keyword.get(opts, :zero_pad, 4)

    import Ecto.Query, only: [from: 2]

    # combine the prefix and suffix for the database key for more control.
    db_lookup_key = prefix <> suffix

    query =
      from t in "transactionkeys",
        where: field(t, :key) == ^db_lookup_key,
        select: field(t, :value)

    try do
      next_string =
        case Repo.one(query) do
          nil -> generate_running_number(prefix, 1, zero_pad, suffix)
          current_value -> generate_running_number(prefix, current_value + 1, zero_pad, suffix)
        end

      {:ok, next_string}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Same as `look_at_next_running_number/2`, but raises on error.

  Returns the formatted running number directly, or raises if the lookup or formatting fails.

  ## Examples

  iex> look_at_next_running_number!("ORD")
  "ORD-0001"                     # if no DB entry

  iex> look_at_next_running_number!("INV", suffix: "CA")
  "INV-0007-CA"                  # if DB entry was 6

  iex> look_at_next_running_number!("BAD_KEY")
  ** (RuntimeError) Failed to get next running number: ...
  """
  @spec look_at_next_running_number!(
          prefix :: String.t(),
          opts :: [suffix: String.t(), zero_pad: non_neg_integer()]
        ) :: String.t()
  def look_at_next_running_number!(prefix, opts \\ []) do
    case look_at_next_running_number(prefix, opts) do
      {:ok, running_number} ->
        running_number

      {:error, reason} ->
        raise "Failed to get next running number: #{inspect(reason)}"
    end
  end

  @doc """
  Generate a formatted identifier composed of:

    1. A required `prefix` string.
    2. A numeric `running_number`, zero-padded to at least `zero_pad` digits.
    3. An optional `suffix` string, only appended (preceded by `-`) if non-empty.

  If the decimal digit count of `running_number` exceeds `zero_pad`, it will be used as-is (no zero-padding).

  ## Parameters

    * `prefix`        — `String.t()`: the static prefix (e.g. `"INV"`).
    * `running_number` — `non_neg_integer()`: the sequence number to format.
    * `zero_pad`      — `non_neg_integer()`: minimum width of the number, default `4`.
    * `suffix`        — `String.t()`: optional suffix; if non-empty, prefixed with `-`.

  ## Returns

    * `String.t()`: a string of the form
      `"<prefix>-<number>"` or `"<prefix>-<number>-<suffix>"`.

  ## Examples

      iex> generate_running_number("ORD", 7,    4, "")
      "ORD-0007"

      iex> generate_running_number("ORD", 123,  4, "US")
      "ORD-0123-US"

      iex> generate_running_number("ORD", 99999, 4, "XL")
      # since 99999 has 5 digits > zero_pad 4, no padding is applied:
      "ORD-99999-XL"

      iex> generate_running_number("TCKT", 42, 6, "END")
      "TCKT-000042-END"
  """
  @spec generate_running_number(
          prefix :: String.t(),
          running_number :: non_neg_integer(),
          zero_pad :: non_neg_integer(),
          suffix :: String.t()
        ) :: String.t()
  def generate_running_number(prefix, running_number, zero_pad \\ 4, suffix) do
    formatted =
      if length(Integer.digits(running_number)) > zero_pad do
        # Number too wide to pad, use as-is
        Integer.to_string(running_number)
      else
        # Zero-pad to the required width
        :io_lib.format("~#{zero_pad}..0B", [running_number])
        |> List.to_string()
      end

    # Build final string with optional suffix
    suffix_part = if suffix == "", do: "", else: "-" <> suffix
    "#{prefix}-#{formatted}#{suffix_part}"
  end

  @spec format_with_timex(template :: String.t()) :: String.t()
  defp format_with_timex(template) do
    # Regex to find placeholders in the format {<timex_format>}
    regex = ~r/\{([^}]+)\}/

    String.replace(template, regex, fn match ->
      case Regex.run(~r/\{([^}]+)\}/, match) do
        [_, format] ->
          try do
            Timex.format!(Timex.now(), "{" <> format <> "}")
          rescue
            Timex.Format.FormatError -> "INVALID_FORMAT"
          end

        _ ->
          match
      end
    end)
  end
end
