defmodule Phoexnip.AddressService do
  @moduledoc """
  Provides functions to list, fetch, and create Address records.
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Address

  @doc """
  Returns all address records.

  ## Examples

      iex> Phoexnip.AddressService.list()
      [%Phoexnip.Address{}, ...]
  """
  @spec list() :: [Address.t()]
  def list do
    Repo.all(Address)
  end

  @doc """
  Fetches a single address by its primary key. Raises if not found.

  ## Parameters

    * `id` — the primary key, either an integer or binary (UUID).

  ## Examples

      iex> Phoexnip.AddressService.get!(1)
      %Phoexnip.Address{id: 1, ...}

      iex> Phoexnip.AddressService.get!("3fa85f64-5717-4562-b3fc-2c963f66afa6")
      %Phoexnip.Address{id: "3fa85f64-5717-4562-b3fc-2c963f66afa6", ...}

      iex> Phoexnip.AddressService.get!(9999)
      ** (Ecto.NoResultsError)
  """
  @spec get!(id :: integer() | binary()) :: Address.t()
  def get!(id), do: Repo.get!(Address, id)

  @doc """
  Fetches a single address by a map or keyword list of fields. Raises if not found.

  ## Parameters

    * `params` — a map or keyword list of field-value pairs to search by.

  ## Examples

      iex> Phoexnip.AddressService.get_by!(city: "Metropolis")
      %Phoexnip.Address{city: "Metropolis", ...}

      iex> Phoexnip.AddressService.get_by!(%{postcode: "12345"})
      %Phoexnip.Address{postcode: "12345", ...}

      iex> Phoexnip.AddressService.get_by!(city: "Nowhere")
      ** (Ecto.NoResultsError)
  """
  @spec get_by!(params :: Keyword.t(any()) | map()) :: Address.t()
  def get_by!(params), do: Repo.get_by!(Address, params)

  @doc """
  Creates a new address record from the given attributes.

  ## Parameters

    * `attrs` — a map of address fields (optional, defaults to an empty map).

  ## Returns

    * `{:ok, %Address{}}` on success
    * `{:error, %Ecto.Changeset{}}` on failure

  ## Examples

      iex> attrs = %{line1: "123 Main St", city: "Metropolis"}
      iex> Phoexnip.AddressService.create(attrs)
      {:ok, %Phoexnip.Address{line1: "123 Main St", city: "Metropolis", ...}}

      iex> Phoexnip.AddressService.create(%{})
      {:error, %Ecto.Changeset{}}
  """
  @spec create(attrs :: map()) :: {:ok, Address.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %Address{}
    |> Address.changeset(attrs)
    |> Repo.insert()
  end
end
