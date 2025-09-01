defmodule Phoexnip.Settings.ApiCredentialService do
  @moduledoc """
  Service layer for managing `ApiCredential` records.

  Provides functions to retrieve, create, and update API credentials,
  handling decryption automatically on retrieval.
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Settings.ApiCredential

  @doc """
  Retrieves the `ApiCredential` struct for the given `job`,
  decrypting the `credential` field before returning.

  Returns `nil` if no record is found.
  """
  @spec get_credentials(String.t()) :: ApiCredential.t() | nil
  def get_credentials(job) when is_binary(job) do
    Repo.get_by(ApiCredential, job: job)
    |> ApiCredential.decrypt_credential()
  end

  @doc """
  Creates a new `ApiCredential` record with the given attributes.

  Encrypts the `credential` field if present. Returns
  `{:ok, %ApiCredential{}}` on success, or `{:error, changeset}` on failure.
  """
  @spec create(map()) :: {:ok, ApiCredential.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) when is_map(attrs) do
    %ApiCredential{}
    |> ApiCredential.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing `ApiCredential` record with the given attributes.

  Re-encrypts the `credential` field if it has changed. Returns
  `{:ok, %ApiCredential{}}` on success, or `{:error, changeset}` on failure.
  """
  @spec update(ApiCredential.t(), map()) ::
          {:ok, ApiCredential.t()} | {:error, Ecto.Changeset.t()}
  def update(%ApiCredential{} = apicredentials, attrs) when is_map(attrs) do
    apicredentials
    |> ApiCredential.changeset(attrs)
    |> Repo.update()
  end
end
