defmodule Phoexnip.DateUtils do
  @moduledoc """
  A collection of date‐and‐time helpers built on Timex, for parsing, formatting, and calculating
  future dates by weekday.

  ## Formatting

    * `formatDate/3`
      - Parses inputs of various kinds (`Date.t`, `NaiveDateTime.t`, `DateTime.t`, or ISO strings).
      - Converts to a target timezone (either provided or the local zone, falling back to UTC).
      - Formats the result according to a Timex format string (default `"{0D}/{0M}/{YYYY} {h24}:{m}"`).
      - Returns `""` on parse failure.

    * `ensure_datetime_format/1`
      - Accepts structs or strings, and guarantees a `YYYY-MM-DD HH:MM:SS` (or ISO `"T"`) result by
        appending `" 00:00:00"` when necessary.

  ## Weekday Calculations

    * `next_weekday/1-2`
      - Given a weekday name (`"monday"`, …, `"all"`) or integer `0..6` (Sun–Sat), returns the next
        date matching that day.
      - `"all"` yields tomorrow plus one week.
      - Invalid strings return `{:error, "Invalid weekday"}`.

    * `next_week_after/2`
      - Like `next_weekday`, but computes the next occurrence *after* a given `Date.t`.
      - Supports strings (`"monday"`, `"all"`) or integers `0..6`.

    * `next_or_same_weekday_after_date/2`
      - Returns the next or *same* date on/after the given date matching a weekday string.
      - `"all"` is treated as simply the next day.

  These utilities centralize complex date‐parsing logic and weekday arithmetic in one place, ensuring
  consistent behavior across your application.
  """

  alias Timex

  @doc """
  Parses and formats a date value according to the given Timex format string and timezone.

  Accepts `date` as:
    * a `Date.t()`, `NaiveDateTime.t()`, or `DateTime.t()` struct — used directly
    * an ISO-8601 datetime string — parsed with `Timex.parse/2`
    * an ISO-8601 date string — parsed with `Date.from_iso8601/1` and converted to midnight in the target timezone
    * any other value or a failed parse — returns `""`

  The optional `format` string defaults to `"{0D}/{0M}/{YYYY} {h24}:{m}"`.
  The optional `user_timezone` (default `nil`) may be either:
    * a timezone name (string) to convert into, or
    * omitted/`nil` to use the local timezone returned by `Timex.Timezone.local/0`
    * if `Timex.Timezone.local/0` errors, falls back to `"Etc/UTC"`

  Always returns a formatted string, or `""` on parse failure.

  ## Examples

      iex> formatDate(~D[2025-07-18])
      "18/07/2025 00:00"

      iex> formatDate("2025-07-18T15:30:00Z", "{YYYY}-{0M}-{0D}", "America/New_York")
      "2025-07-18"

      iex> formatDate("invalid-date")
      ""
  """
  @spec formatDate(
          date :: Date.t() | NaiveDateTime.t() | DateTime.t() | String.t(),
          format :: String.t(),
          user_timezone :: String.t() | nil
        ) :: String.t()
  def formatDate(date, format \\ "{0D}/{0M}/{YYYY} {h24}:{m}", user_timezone \\ nil) do
    get_timezone_name = fn ->
      if is_binary(user_timezone) do
        user_timezone
      else
        case Timex.Timezone.local() do
          %Timex.TimezoneInfo{full_name: tz_name} ->
            tz_name

          {:error, _reason} ->
            "Etc/UTC"
        end
      end
    end

    parsed_date =
      cond do
        match?(%Date{}, date) or match?(%NaiveDateTime{}, date) or match?(%DateTime{}, date) ->
          date

        is_binary(date) ->
          case Timex.parse(date, "{ISO:Extended}") do
            {:ok, parsed} ->
              parsed

            {:error, _} ->
              case Date.from_iso8601(date) do
                {:ok, parsed_date} ->
                  timezone_name = get_timezone_name.()
                  DateTime.new!(parsed_date, ~T[00:00:00], timezone_name)

                {:error, _} ->
                  nil
              end
          end

        true ->
          nil
      end

    if parsed_date != nil do
      final_timezone =
        if is_binary(user_timezone),
          do: user_timezone,
          else: Timex.Timezone.local()

      parsed_date
      |> Timex.Timezone.convert(final_timezone)
      |> Timex.format!(format)
    else
      ""
    end
  end

  @doc """
  Ensures that a value is in a full datetime format (ending in `HH:MM:SS`), appending `" 00:00:00"` when needed.

  ## Behavior

    * If `value` is a `DateTime` or `NaiveDateTime` struct, it is returned unchanged.
    * If `value` is a string:
      - If it already contains `"T"` (ISO format) or a space, returns it as-is.
      - Otherwise, appends `" 00:00:00"`.
    * For any other type:
      1. Converts it to a string via `to_string/1`.
      2. Applies the same logic as for a binary (checks for `"T"` or space, or appends `" 00:00:00"`).

  Always returns either the original struct or a string in the form `YYYY-MM-DD HH:MM:SS` (or with a `"T"` if present).

  ## Examples

      iex> ensure_datetime_format(~N[2025-07-18 15:30:45])
      ~N[2025-07-18 15:30:45]

      iex> ensure_datetime_format("2025-07-18T15:30:45")
      "2025-07-18T15:30:45"

      iex> ensure_datetime_format("2025-07-18")
      "2025-07-18 00:00:00"

      iex> ensure_datetime_format(20250718)
      "20250718 00:00:00"
  """
  @spec ensure_datetime_format(value :: DateTime.t() | NaiveDateTime.t() | String.t() | any()) ::
          DateTime.t() | NaiveDateTime.t() | String.t()
  def ensure_datetime_format(value) do
    cond do
      # If it's already a DateTime or NaiveDateTime struct, return it as is
      is_struct(value, DateTime) or is_struct(value, NaiveDateTime) ->
        value

      # For string values, apply the original formatting logic
      is_binary(value) ->
        if String.contains?(value, "T") or String.contains?(value, " ") do
          value
        else
          value <> " 00:00:00"
        end

      # For other types, convert to string first and then format
      true ->
        string_value = to_string(value)

        if String.contains?(string_value, "T") or String.contains?(string_value, " ") do
          string_value
        else
          string_value <> " 00:00:00"
        end
    end
  end

  @weekdays %{
    "sunday" => 0,
    "monday" => 1,
    "tuesday" => 2,
    "wednesday" => 3,
    "thursday" => 4,
    "friday" => 5,
    "saturday" => 6,
    "all" => 7
  }

  @doc """
  Returns the next date for the given `weekday`.

  Accepts:

    * A string (case-insensitive) like `"monday"`, `"tuesday"`, etc.
    * The atom `:all` to mean “every day” (which yields tomorrow plus one week).
    * An integer 0..6, where 0 = Sunday, 1 = Monday, …, 6 = Saturday.

  For a string, it is downcased, looked up in `@weekdays`, and delegated.
  If the string isn’t a valid weekday, returns `{:error, "Invalid weekday"}`.

  For `:all`, returns tomorrow shifted by 7 days.
  For an integer n in 0..6, computes the next occurrence of that weekday (if today is n, returns one week ahead).

  ## Examples

      iex> # Suppose today is Friday, 2025-07-18
      iex> next_weekday("monday")
      ~D[2025-07-21]

      iex> next_weekday(:all)
      ~D[2025-07-26]

      iex> next_weekday(5)
      ~D[2025-07-25]

      iex> next_weekday("funday")
      {:error, "Invalid weekday"}
  """
  @spec next_weekday(weekday :: String.t()) :: Date.t() | {:error, String.t()}
  def next_weekday(weekday) when is_binary(weekday) do
    case Map.get(@weekdays, String.downcase(weekday)) do
      nil -> {:error, "Invalid weekday"}
      7 -> next_weekday(:all)
      day -> next_weekday(day)
    end
  end

  @spec next_weekday(:all) :: Date.t()
  def next_weekday(:all) do
    today = Timex.today()
    tomorrow = Timex.shift(today, days: 1)

    Timex.shift(tomorrow, days: 7)
  end

  @spec next_weekday(weekday :: integer()) :: Date.t()
  def next_weekday(weekday) when is_integer(weekday) and weekday in 0..6 do
    today = Timex.today()
    days_to_add = rem(weekday - Timex.weekday(today) + 7, 7)
    days_to_add = if days_to_add == 0, do: 7, else: days_to_add
    Timex.shift(today, days: days_to_add)
  end

  @doc """
  Returns the next date after `date` that falls on the specified `weekday`.

  Accepts `weekday` as:
    * A string (case-insensitive) `"sunday" | ... | "saturday" | "all"`
      - `"all"` returns tomorrow (`date + 1 day`)
      - Invalid strings return `{:error, "Invalid weekday"}`
    * An integer `0..6` where 0 = Sunday, 1 = Monday, …, 6 = Saturday.

  ## Examples

      iex> # Assume date = ~D[2025-07-18] (Friday)
      iex> next_week_after(~D[2025-07-18], "monday")
      ~D[2025-07-21]

      iex> next_week_after(~D[2025-07-18], "all")
      ~D[2025-07-19]

      iex> next_week_after(~D[2025-07-18], 5)
      ~D[2025-07-25]

      iex> next_week_after(~D[2025-07-18], "funday")
      {:error, "Invalid weekday"}
  """
  @spec next_week_after(date :: Date.t(), weekday :: String.t()) ::
          Date.t() | {:error, String.t()}
  def next_week_after(date, weekday) when is_binary(weekday) do
    case Map.get(@weekdays, String.downcase(weekday)) do
      nil -> {:error, "Invalid weekday"}
      7 -> Timex.shift(date, days: 1)
      day -> next_week_after(date, day)
    end
  end

  @spec next_week_after(date :: Date.t(), weekday :: integer()) :: Date.t()
  def next_week_after(date, weekday) when is_integer(weekday) and weekday in 0..6 do
    # Adjust Timex.weekday numbering: Sunday = 7 here if weekday == 0
    weekday = if weekday == 0, do: 7, else: weekday

    # First shift ahead one full week
    base_date = Timex.shift(date, days: 7)
    # 1 = Monday, …, 7 = Sunday
    current_day = Timex.weekday(base_date)

    days_to_add =
      case rem(weekday - current_day + 7, 7) do
        0 -> 7
        n -> n
      end

    Timex.shift(base_date, days: days_to_add)
  end

  @doc """
  Returns the next or same date on or after `date` matching the given `weekday` string.

  - `weekday` may be one of (case-insensitive):
    `"sunday"`, `"monday"`, `"tuesday"`, `"wednesday"`,
    `"thursday"`, `"friday"`, `"saturday"`, or `"all"`.
  - `"all"` is treated as “next day” regardless of weekday.
  - For other valid weekday names, computes the offset from `date` to the next occurrence of that day (including the same day).

  Raises `CaseClauseError` if `weekday` is not one of the above strings.

  ## Examples

      iex> next_or_same_weekday_after_date(~D[2025-07-18], "monday")
      ~D[2025-07-21]

      iex> next_or_same_weekday_after_date(~D[2025-07-20], "monday")
      ~D[2025-07-20]

      iex> next_or_same_weekday_after_date(~D[2025-07-18], "all")
      ~D[2025-07-19]

      iex> next_or_same_weekday_after_date(~D[2025-07-18], "Funday")
      ** (CaseClauseError)
  """
  @spec next_or_same_weekday_after_date(
          date :: Date.t(),
          weekday :: String.t()
        ) :: Date.t()
  def next_or_same_weekday_after_date(%Date{} = date, weekday) when is_binary(weekday) do
    downcased = String.downcase(weekday)

    case @weekdays[downcased] do
      7 ->
        # "all" means: next day, regardless of weekday
        Date.add(date, 1)

      target_day_num ->
        # Convert 1..7 (Mon–Sun) → 0..6
        current_day_num = Date.day_of_week(date) |> rem(7)

        days_ahead = rem(target_day_num - current_day_num + 7, 7)

        Date.add(date, days_ahead)
    end
  end
end
