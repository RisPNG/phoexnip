defmodule Phoexnip.Masterdata.GroupsService do
  @moduledoc """
  The Masterdata context responsible for managing `Groups` records.

  This module provides functions to:
    * list all groups
    * fetch a single group by ID or by attributes (with or without raising)
    * create, update, and delete groups
    * build changesets for tracking group changes
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Masterdata.Groups

  @doc """
  Returns all groups, ordered ascending by their `sort` field.

  ## Examples

      iex> list()
      [%Groups{sort: 1, code: "HR", name: "Human Resources"}, ...]
  """
  @spec list() :: [Groups.t()]
  def list do
    Repo.all(from d in Groups, order_by: [asc: d.sort])
  end

  @doc """
  Fetches a single group by its primary key.

  Raises `Ecto.NoResultsError` if no group with the given ID exists.

  ## Examples

      iex> get!(123)
      %Groups{id: 123, code: "HR", name: "Human Resources"}

      iex> get!(456)
      ** (Ecto.NoResultsError)
  """
  @spec get!(term()) :: Groups.t()
  def get!(id), do: Repo.get!(Groups, id)

  @doc """
  Fetches a single group by its primary key.

  Returns `nil` if no group with the given ID exists.

  ## Examples

      iex> get(123)
      %Groups{id: 123, code: "HR", name: "Human Resources"}

      iex> get(456)
      nil
  """
  @spec get(term()) :: Groups.t() | nil
  def get(id), do: Repo.get(Groups, id)

  @doc """
  Fetches a single group matching the given attributes map.

  Raises `Ecto.NoResultsError` if none match.

  ## Examples

      iex> get_by!(%{code: "HR"})
      %Groups{code: "HR", name: "Human Resources"}

      iex> get_by!(%{code: "XX"})
      ** (Ecto.NoResultsError)
  """
  @spec get_by!(map()) :: Groups.t()
  def get_by!(attrs) when is_map(attrs), do: Repo.get_by!(Groups, attrs)

  @doc """
  Fetches a single group matching the given attributes map.

  Returns `nil` if none match.

  ## Examples

      iex> get_by(%{name: "Finance"})
      %Groups{code: "FN", name: "Finance"}

      iex> get_by(%{code: "ZZ"})
      nil
  """
  @spec get_by(map()) :: Groups.t() | nil
  def get_by(attrs) when is_map(attrs), do: Repo.get_by(Groups, attrs)

  @doc """
  Creates a new group record with the given attributes.

  Returns `{:ok, %Groups{}}` on success or
  `{:error, %Ecto.Changeset{}}` if validation fails.

  ## Examples

      iex> create(%{sort: 1, code: "HR", name: "Human Resources"})
      {:ok, %Groups{}}

      iex> create(%{code: nil})
      {:error, %Ecto.Changeset{}}
  """
  @spec create(map()) :: {:ok, Groups.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %Groups{}
    |> Groups.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing group record with the given attributes.

  Returns `{:ok, %Groups{}}` on success or
  `{:error, %Ecto.Changeset{}}` if validation fails.

  ## Examples

      iex> update(dept, %{name: "HR & Admin"})
      {:ok, %Groups{name: "HR & Admin"}}

      iex> update(dept, %{code: nil})
      {:error, %Ecto.Changeset{}}
  """
  @spec update(Groups.t(), map()) ::
          {:ok, Groups.t()} | {:error, Ecto.Changeset.t()}
  def update(%Groups{} = group, attrs) do
    group
    |> Groups.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes the given group record.

  Returns `{:ok, %Groups{}}` on success or
  `{:error, %Ecto.Changeset{}}` if the delete fails.

  ## Examples

      iex> delete(dept)
      {:ok, %Groups{}}

      iex> delete(nonexistent_dept)
      {:error, %Ecto.Changeset{}}
  """
  @spec delete(Groups.t()) :: {:ok, Groups.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Groups{} = group) do
    Repo.delete(group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking changes to a group.

  Useful for form rendering and validations without persisting.

  ## Examples

      iex> change(dept)
      %Ecto.Changeset{data: %Groups{}, changes: %{}}

      iex> change(dept, %{name: "Admin"})
      %Ecto.Changeset{data: %Groups{}, changes: %{name: "Admin"}}
  """
  @spec change(Groups.t(), map()) :: Ecto.Changeset.t()
  def change(%Groups{} = group, attrs \\ %{}) do
    Groups.changeset(group, attrs)
  end
end
