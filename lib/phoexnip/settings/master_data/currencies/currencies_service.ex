defmodule Phoexnip.Masterdata.CurrenciesService do
  @moduledoc """
  The Masterdata context responsible for managing `Currencies` records.

  This module provides functions to:
    * list all currencies
    * fetch a single currencies by ID or by attributes (with or without raising)
    * create, update, and delete currencies
    * build changesets for tracking currencies changes
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Masterdata.Currencies

  @doc """
  Returns all currencies, ordered ascending by their `sort` field.

  ## Examples

      iex> list()
      [%Currencies{sort: 1, code: "USD", name: "US Dollar", exchange_rate: %Decimal{}}, ...]
  """
  @spec list() :: [Currencies.t()]
  def list do
    Repo.all(from c in Currencies, order_by: [asc: c.sort])
  end

  @doc """
  Fetches a single currencies by its primary key.

  Raises `Ecto.NoResultsError` if no currencies with the given ID exists.

  ## Examples

      iex> get!(123)
      %Currencies{id: 123, code: "USD", name: "US Dollar", exchange_rate: %Decimal{}}

      iex> get!(456)
      ** (Ecto.NoResultsError)
  """
  @spec get!(term()) :: Currencies.t()
  def get!(id), do: Repo.get!(Currencies, id)

  @doc """
  Fetches a single currencies by its primary key.

  Returns `nil` if no currencies with the given ID exists.

  ## Examples

      iex> get(123)
      %Currencies{id: 123, code: "USD", name: "US Dollar", exchange_rate: %Decimal{}}

      iex> get(456)
      nil
  """
  @spec get(term()) :: Currencies.t() | nil
  def get(id), do: Repo.get(Currencies, id)

  @doc """
  Fetches a single currencies matching the given attributes map.

  Raises `Ecto.NoResultsError` if none match.

  ## Examples

      iex> get_by!(%{code: "EUR"})
      %Currencies{code: "EUR", name: "Euro", exchange_rate: %Decimal{}}

      iex> get_by!(%{code: "XXX"})
      ** (Ecto.NoResultsError)
  """
  @spec get_by!(map()) :: Currencies.t()
  def get_by!(attrs) when is_map(attrs), do: Repo.get_by!(Currencies, attrs)

  @doc """
  Fetches a single currencies matching the given attributes map.

  Returns `nil` if none match.

  ## Examples

      iex> get_by(%{code: "EUR"})
      %Currencies{code: "EUR", name: "Euro", exchange_rate: %Decimal{}}

      iex> get_by(%{code: "XXX"})
      nil
  """
  @spec get_by(map()) :: Currencies.t() | nil
  def get_by(attrs) when is_map(attrs), do: Repo.get_by(Currencies, attrs)

  @doc """
  Creates a new currencies record with the given attributes.

  Returns `{:ok, %Currencies{}}` on success or
  `{:error, %Ecto.Changeset{}}` if validation fails.

  ## Examples

      iex> create(%{sort: 1, code: "USD", name: "US Dollar", exchange_rate: "1.0"})
      {:ok, %Currencies{}}

      iex> create(%{code: nil})
      {:error, %Ecto.Changeset{}}
  """
  @spec create(map()) :: {:ok, Currencies.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %Currencies{}
    |> Currencies.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing currencies record with the given attributes.

  Returns `{:ok, %Currencies{}}` on success or
  `{:error, %Ecto.Changeset{}}` if validation fails.

  ## Examples

      iex> update(currencies, %{name: "US Dollar"})
      {:ok, %Currencies{name: "US Dollar"}}

      iex> update(currencies, %{code: nil})
      {:error, %Ecto.Changeset{}}
  """
  @spec update(Currencies.t(), map()) ::
          {:ok, Currencies.t()} | {:error, Ecto.Changeset.t()}
  def update(%Currencies{} = currencies, attrs) do
    currencies
    |> Currencies.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes the given currencies record.

  Returns `{:ok, %Currencies{}}` on success or
  `{:error, %Ecto.Changeset{}}` if the delete fails.

  ## Examples

      iex> delete(currencies)
      {:ok, %Currencies{}}

      iex> delete(nonexistent_currencies)
      {:error, %Ecto.Changeset{}}
  """
  @spec delete(Currencies.t()) :: {:ok, Currencies.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Currencies{} = currencies) do
    Repo.delete(currencies)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking changes to a currencies.

  Useful for form rendering and validations without persisting.

  ## Examples

      iex> change(currencies)
      %Ecto.Changeset{data: %Currencies{}, changes: %{}}

      iex> change(currencies, %{name: "Euro"})
      %Ecto.Changeset{data: %Currencies{}, changes: %{name: "Euro"}}
  """
  @spec change(Currencies.t(), map()) :: Ecto.Changeset.t()
  def change(%Currencies{} = currencies, attrs \\ %{}) do
    Currencies.changeset(currencies, attrs)
  end
end
