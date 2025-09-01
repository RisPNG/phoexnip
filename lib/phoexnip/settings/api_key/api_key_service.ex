defmodule Phoexnip.Settings.ApiKeyService do
  @moduledoc """
  Context module for managing API keys.

  Provides functions to generate, retrieve, and delete API key records.
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Settings.ApiKey

  @doc """
  Generates and stores a new API key.

  Builds and inserts an `%ApiKey{}` struct with:
    * a random 32-byte base64-encoded `:key`
    * a random 64-byte base64-encoded `:refresh_key`
    * `:valid_until` set to 1 day from now
    * `:refresh_until` set to 7 days from now

  ## Examples

      iex> generate_api_key("service_name")
      {:ok, %ApiKey{}}

      iex> generate_api_key(nil)
      {:error, %Ecto.Changeset{}}

  ## Parameters

    - `given_to` (`String.t()`): identifier for whom the key is issued

  ## Returns

    - `{:ok, %ApiKey{}}` on success
    - `{:error, %Ecto.Changeset{}}` on failure
  """
  @spec generate_api_key(String.t()) ::
          {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def generate_api_key(given_to) do
    # Generate a random 32-character API key
    api_key = :crypto.strong_rand_bytes(32) |> Base.encode64() |> binary_part(0, 43)
    refresh_key = :crypto.strong_rand_bytes(64) |> Base.encode64() |> binary_part(0, 86)

    utc_now = Timex.now("Etc/UTC")
    valid_until = Timex.shift(utc_now, days: 1)
    refresh_until = Timex.shift(utc_now, days: 7)

    changeset =
      ApiKey.changeset(%ApiKey{}, %{
        key: api_key,
        given_to: given_to,
        valid_until: valid_until,
        refresh_key: refresh_key,
        refresh_until: refresh_until
      })

    case Repo.insert(changeset) do
      {:ok, api_key} -> {:ok, api_key}
      {:error, cs} -> {:error, cs}
    end
  end

  @doc """
  Retrieves an API key by the given criteria.

  ## Examples

      iex> get_by!(key: "abc123")
      %ApiKey{key: "abc123", ...}

      iex> get_by!(given_to: "unknown")
      nil

  ## Parameters

    - `args` (`keyword()` or `map()`): fields to query by

  ## Returns

    - `%ApiKey{}` if a matching record is found
    - `nil` if no match exists
  """
  @spec get_by!(keyword() | map()) :: ApiKey.t() | nil
  def get_by!(args), do: Repo.get_by(ApiKey, args)

  @doc """
  Deletes an existing API key record.

  ## Examples

      iex> delete(api_key_struct)
      {:ok, %ApiKey{}}

      iex> delete(invalid_struct)
      {:error, %Ecto.Changeset{}}

  ## Parameters

    - `apikey` (`%ApiKey{}`): the API key struct to delete

  ## Returns

    - `{:ok, %ApiKey{}}` on successful deletion
    - `{:error, %Ecto.Changeset{}}` on failure
  """
  @spec delete(ApiKey.t()) :: {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def delete(%ApiKey{} = apikey) do
    Repo.delete(apikey)
  end
end
