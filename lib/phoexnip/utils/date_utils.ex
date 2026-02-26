defmodule Phoexnip.DateUtils do
  @moduledoc """
  A collection of date‐and‐time helpers built on Timex, for parsing and formatting.

  ## Formatting

    * `formatDate/3`
      - Parses inputs of various kinds (`Date.t`, `NaiveDateTime.t`, `DateTime.t`, or ISO strings).
      - Converts to a target timezone (either provided or the local zone, falling back to UTC).
      - Formats the result according to a Timex format string (default `"{0D}/{0M}/{YYYY} {h24}:{m}"`).
      - Returns `""` on parse failure.
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
end
