defmodule Phoexnip.Masterdata.CurrencyService do
  @moduledoc """
  The Masterdata context responsible for managing `Currency` records.

  This module provides functions to:
    * list all currency
    * fetch a single currency by ID or by attributes (with or without raising)
    * create, update, and delete currency
    * build changesets for tracking currency changes
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Masterdata.Currency

  @doc """
  Returns all currency, ordered ascending by their `sort` field.

  ## Examples

      iex> list()
      [%Currency{sort: 1, code: "USD", name: "US Dollar", exchange_rate: %Decimal{}}, ...]
  """
  @spec list() :: [Currency.t()]
  def list do
    Repo.all(from c in Currency, order_by: [asc: c.sort])
  end

  @doc """
  Fetches a single currency by its primary key.

  Raises `Ecto.NoResultsError` if no currency with the given ID exists.

  ## Examples

      iex> get!(123)
      %Currency{id: 123, code: "USD", name: "US Dollar", exchange_rate: %Decimal{}}

      iex> get!(456)
      ** (Ecto.NoResultsError)
  """
  @spec get!(term()) :: Currency.t()
  def get!(id), do: Repo.get!(Currency, id)

  @doc """
  Fetches a single currency by its primary key.

  Returns `nil` if no currency with the given ID exists.

  ## Examples

      iex> get(123)
      %Currency{id: 123, code: "USD", name: "US Dollar", exchange_rate: %Decimal{}}

      iex> get(456)
      nil
  """
  @spec get(term()) :: Currency.t() | nil
  def get(id), do: Repo.get(Currency, id)

  @doc """
  Fetches a single currency matching the given attributes map.

  Raises `Ecto.NoResultsError` if none match.

  ## Examples

      iex> get_by!(%{code: "EUR"})
      %Currency{code: "EUR", name: "Euro", exchange_rate: %Decimal{}}

      iex> get_by!(%{code: "XXX"})
      ** (Ecto.NoResultsError)
  """
  @spec get_by!(map()) :: Currency.t()
  def get_by!(attrs) when is_map(attrs), do: Repo.get_by!(Currency, attrs)

  @doc """
  Fetches a single currency matching the given attributes map.

  Returns `nil` if none match.

  ## Examples

      iex> get_by(%{code: "EUR"})
      %Currency{code: "EUR", name: "Euro", exchange_rate: %Decimal{}}

      iex> get_by(%{code: "XXX"})
      nil
  """
  @spec get_by(map()) :: Currency.t() | nil
  def get_by(attrs) when is_map(attrs), do: Repo.get_by(Currency, attrs)

  @doc """
  Creates a new currency record with the given attributes.

  Returns `{:ok, %Currency{}}` on success or
  `{:error, %Ecto.Changeset{}}` if validation fails.

  ## Examples

      iex> create(%{sort: 1, code: "USD", name: "US Dollar", exchange_rate: "1.0"})
      {:ok, %Currency{}}

      iex> create(%{code: nil})
      {:error, %Ecto.Changeset{}}
  """
  @spec create(map()) :: {:ok, Currency.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %Currency{}
    |> Currency.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing currency record with the given attributes.

  Returns `{:ok, %Currency{}}` on success or
  `{:error, %Ecto.Changeset{}}` if validation fails.

  ## Examples

      iex> update(currency, %{name: "US Dollar"})
      {:ok, %Currency{name: "US Dollar"}}

      iex> update(currency, %{code: nil})
      {:error, %Ecto.Changeset{}}
  """
  @spec update(Currency.t(), map()) ::
          {:ok, Currency.t()} | {:error, Ecto.Changeset.t()}
  def update(%Currency{} = currency, attrs) do
    currency
    |> Currency.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes the given currency record.

  Returns `{:ok, %Currency{}}` on success or
  `{:error, %Ecto.Changeset{}}` if the delete fails.

  ## Examples

      iex> delete(currency)
      {:ok, %Currency{}}

      iex> delete(nonexistent_currency)
      {:error, %Ecto.Changeset{}}
  """
  @spec delete(Currency.t()) :: {:ok, Currency.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Currency{} = currency) do
    Repo.delete(currency)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking changes to a currency.

  Useful for form rendering and validations without persisting.

  ## Examples

      iex> change(currency)
      %Ecto.Changeset{data: %Currency{}, changes: %{}}

      iex> change(currency, %{name: "Euro"})
      %Ecto.Changeset{data: %Currency{}, changes: %{name: "Euro"}}
  """
  @spec change(Currency.t(), map()) :: Ecto.Changeset.t()
  def change(%Currency{} = currency, attrs \\ %{}) do
    Currency.changeset(currency, attrs)
  end
end
