defmodule Phoexnip.NumberUtils do
  @moduledoc """
  Utility functions for validating numeric values.

  This module provides:

    * `validate_positive_integer/2` – ensure a given value represents a positive integer, falling back to a default if not.
  """

  @doc """
  Validates that the given value represents a positive integer.

  ## Parameters

    * `value` — the input to validate.
      - If it's already an integer > 0, it is returned as-is.
      - Otherwise, if it's a string that can be parsed into an integer > 0, the parsed integer is returned.
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

  @doc """
  Formats a number with space-separated thousands.

  ## Examples

      iex> format_number(1234567)
      "1 234 567"

      iex> format_number(999)
      "999"
  """
  @spec format_number(number :: integer()) :: String.t()
  def format_number(number) when is_integer(number) do
    number |> Integer.to_string() |> add_thousand_separators()
  end

  defp add_thousand_separators(number_string) do
    number_string
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0 ")
    |> String.reverse()
  end
end
