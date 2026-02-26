defmodule Phoexnip.ControllerUtils do
  @moduledoc """
  Utility functions for controller-layer error handling.

  ## Key Features

    * **JSON-friendly changeset errors**
      - `convert_changeset_errors_to_json/1` — walks an `Ecto.Changeset`, replaces placeholders in error messages (e.g. `%{count}`) with actual values, and returns a map of human-readable error strings suitable for API responses.

  These helpers centralize common controller concerns—standardized error formatting—so your Phoenix controllers can remain concise and consistent in how they report validation failures.
  """

  @doc """
  Transforms an Ecto changeset’s errors into a JSON-friendly map.

  Traverses all errors in the given `changeset`, replaces any `%{count}`-style
  placeholders in the error messages with their actual values, and returns a map
  where each key is the field (as an atom) and the value is a list of fully
  rendered error strings.

  ## Examples

      iex> changeset =
      ...>   %Ecto.Changeset{data: %User{}, valid?: false}
      ...>   |> Ecto.Changeset.cast(%{}, [:name])
      ...>   |> Ecto.Changeset.validate_required([:name])
      iex> convert_changeset_errors_to_json(changeset)
      %{name: ["can’t be blank"]}
  """
  @spec convert_changeset_errors_to_json(changeset :: Ecto.Changeset.t()) :: %{
          optional(atom()) => [String.t()]
        }
  def convert_changeset_errors_to_json(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      # The default `msg` includes %{count} etc. placeholders, so we replace them with the actual values
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        # Safely convert key to string, handling atoms, integers, lists, and other types
        key_str =
          case key do
            atom when is_atom(atom) -> Atom.to_string(atom)
            # Use inspect for complex types like lists
            _ -> inspect(key)
          end

        # Convert value to string, handling lists and other non-string values
        value_str =
          case value do
            # Handle atoms
            atom when is_atom(atom) -> Atom.to_string(atom)
            # Join lists with comma for readability
            list when is_list(list) -> Enum.join(list, ", ")
            # Handle other types
            _ -> to_string(value)
          end

        String.replace(acc, "%{#{key_str}}", value_str)
      end)
    end)
  end
end
