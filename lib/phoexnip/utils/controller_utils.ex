defmodule Phoexnip.ControllerUtils do
  @moduledoc """
  Utility functions for controller-layer data transformation and error handling.

  ## Key Features

    * **Atom-safe parameter conversion**
      - `convert_map_to_existing_atom/1` — transforms a map with string or atom keys into a map with only existing atoms as keys, returning an error if any key cannot be converted.
      - `convert_to_existing_atom/1` — attempts to convert a single value (string or atom) into an existing atom, returning a descriptive error on failure.

    * **JSON-friendly changeset errors**
      - `convert_changeset_errors_to_json/1` — walks an `Ecto.Changeset`, replaces placeholders in error messages (e.g. `%{count}`) with actual values, and returns a map of human-readable error strings suitable for API responses.

  These helpers centralize common controller concerns—safe param casting and standardized error formatting—so your Phoenix controllers can remain concise and consistent in how they handle incoming data and report validation failures.
  """

  @doc """
  Converts all keys in the given `map` to existing atoms.

  - If a key is already an atom, it is left unchanged.
  - If a key is a string corresponding to an existing atom, it is converted.
  - If any string key does not correspond to an existing atom, returns an error tuple.

  ## Examples

      iex> convert_map_to_existing_atom(%{"foo" => 1, :bar => 2})
      {:ok, %{foo: 1, bar: 2}}

      iex> convert_map_to_existing_atom(%{"nonexistent_key" => 3})
      {:error, "Invalid key in JSON. Ensure all keys are from existing objects."}
  """
  @spec convert_map_to_existing_atom(map :: %{optional(atom() | String.t()) => any()}) ::
          {:ok, %{optional(atom()) => any()}} | {:error, String.t()}
  def convert_map_to_existing_atom(map) do
    try do
      {:ok,
       Map.new(map, fn {key, value} ->
         key = if is_atom(key), do: key, else: String.to_existing_atom(key)
         {key, value}
       end)}
    rescue
      ArgumentError ->
        {:error, "Invalid key in JSON. Ensure all keys are from existing objects."}
    end
  end

  @doc """
  Attempts to convert the given `value` into an existing atom.

  - If `value` is already an atom, returns `{:ok, value}`.
  - If `value` is a string, attempts `String.to_existing_atom/1`:
    - On success, returns `{:ok, atom}`.
    - If the string does not correspond to an existing atom, rescues and returns an error tuple.

  ## Examples

      iex> convert_to_existing_atom(:foo)
      {:ok, :foo}

      iex> convert_to_existing_atom("bar")
      {:ok, :bar}

      iex> convert_to_existing_atom("nonexistent_atom")
      {:error, "Invalid value: 'nonexistent_atom'. Ensure it is a valid existing atom or convertible string."}
  """
  @spec convert_to_existing_atom(value :: atom() | String.t()) ::
          {:ok, atom()} | {:error, String.t()}
  def convert_to_existing_atom(value) do
    try do
      if is_atom(value) do
        {:ok, value}
      else
        {:ok, String.to_existing_atom(value)}
      end
    rescue
      ArgumentError ->
        {:error,
         "Invalid value: '#{value}'. Ensure it is a valid existing atom or convertible string."}
    end
  end

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
