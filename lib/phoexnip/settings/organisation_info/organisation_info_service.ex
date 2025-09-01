defmodule Phoexnip.Settings.OrganisationInfoService do
  @moduledoc """
  The Settings context for managing OrganisationInfo records.

  Provides functions to retrieve, create, update, and track changes to OrganisationInfo,
  including associated addresses.
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Settings.OrganisationInfo
  alias Phoexnip.Address

  @doc """
  Retrieves the OrganisationInfo record.

  If none exists, returns a new `%OrganisationInfo{}` struct with default billing
  and delivery addresses. Otherwise, returns the existing record with
  addresses preloaded.
  """
  @spec get_organisation_info() :: OrganisationInfo.t()
  def get_organisation_info do
    OrganisationInfo
    |> first()
    |> Repo.one()
    |> case do
      nil ->
        %OrganisationInfo{
          address: [
            %Address{guid: Ecto.UUID.generate(), category: "BILLING", sequence: 1},
            %Address{guid: Ecto.UUID.generate(), category: "DELIVERY", sequence: 1}
          ]
        }

      info ->
        info |> Repo.preload(:address)
    end
  end

  @doc """
  Retrieves a `%OrganisationInfo{}` by its `id`.

  Raises `Ecto.NoResultsError` if not found. Preloads associated addresses.
  """
  @spec get!(id :: integer()) :: OrganisationInfo.t()
  def get!(id), do: Repo.get!(OrganisationInfo, id) |> Repo.preload(:address)

  @doc """
  Creates a new `%OrganisationInfo{}` with the given attributes.

  Returns `{:ok, OrganisationInfo}` on success or `{:error, Ecto.Changeset}` on failure.
  """
  @spec create(attrs :: map()) :: {:ok, OrganisationInfo.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %OrganisationInfo{}
    |> OrganisationInfo.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing `%OrganisationInfo{}` with the given attributes.

  Returns `{:ok, OrganisationInfo}` on success or `{:error, Ecto.Changeset}` on failure.
  """
  @spec update(organisation_info :: OrganisationInfo.t(), attrs :: map()) ::
          {:ok, OrganisationInfo.t()} | {:error, Ecto.Changeset.t()}
  def update(%OrganisationInfo{} = organisation_info, attrs) do
    organisation_info
    |> OrganisationInfo.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking changes to a `%OrganisationInfo{}`.
  """
  @spec change(organisation_info :: OrganisationInfo.t(), attrs :: map()) :: Ecto.Changeset.t()
  def change(%OrganisationInfo{} = organisation_info, attrs \\ %{}) do
    OrganisationInfo.changeset(organisation_info, attrs)
  end
end
