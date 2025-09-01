defmodule Phoexnip.NumberUtils do
  @moduledoc """
  Utility functions for formatting and validating numeric values.

  This module provides:

    * `format_number/1` – convert an integer into a string with thousand separators.
    * `add_thousand_separators/1` – insert commas into the integer portion of a numeric string, preserving any decimal part.
    * `validate_positive_integer/2` – ensure a given value represents a positive integer, falling back to a default if not.

  These helpers make it easy to present large numbers in a human‐readable form and to guard against invalid or non‐positive integer inputs.
  """

  @doc """
  Formats an integer by inserting thousand separators.

  ## Parameters

    * `number` — an integer to format (e.g. `1234567`).

  ## Returns

    * A `String.t()` with separators every three digits (e.g. `"1,234,567"`).
  """
  @spec format_number(number :: integer()) :: String.t()
  def format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> add_thousand_separators()
  end

  @doc """
  Inserts commas as thousand separators into the integer part of a numeric string,
  preserving any existing decimal part.

  ## Examples

      iex> add_thousand_separators("1234")
      "1,234"

      iex> add_thousand_separators("1234567.89")
      "1,234,567.89"

  ## Parameters

    * `number_string` — a string representing a number, optionally with a decimal part.

  ## Returns

    * A `String.t()` with commas inserted every three digits in the integer portion.
  """
  @spec add_thousand_separators(number_string :: String.t()) :: String.t()
  def add_thousand_separators(number_string) do
    case String.split(number_string, ".") do
      [integer_part] ->
        integer_part
        |> String.reverse()
        |> String.replace(~r/.{3}(?=.)/, "\\0,")
        |> String.reverse()

      [integer_part, decimal_part] ->
        formatted_integer =
          integer_part
          |> String.reverse()
          |> String.replace(~r/.{3}(?=.)/, "\\0,")
          |> String.reverse()

        formatted_integer <> "." <> decimal_part
    end
  end

  @doc """
  Validates that the given value represents a positive integer.

  ## Parameters

    * `value` — the input to validate.
      - If it’s already an integer > 0, it is returned as-is.
      - Otherwise, if it’s a string that can be parsed into an integer > 0, the parsed integer is returned.
    * `default` — the integer to return if validation or parsing fails (or the parsed integer is not > 0).

  ## Returns

    * A positive integer: either the original integer, the parsed integer, or `default` if validation fails.
  """
  @spec validate_positive_integer(value :: integer() | String.t(), default :: integer()) ::
          integer()
  def validate_positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  def validate_positive_integer(value, default) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end
end
