defmodule Phoexnip.ServiceUtils do
  @moduledoc """
  Generic service utilities for common CRUD operations across all entity types.

  This module provides a consolidated interface for standard database operations,
  eliminating code duplication across individual service modules.

  All functions require a `module` parameter to specify which schema/entity to operate on.
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo

  @doc """
  Returns all records for the given module/schema.

  ## Examples
      iex> ServiceUtils.list(MyApp.User)
      [%MyApp.User{}, ...]
  """
  @spec list(module()) :: [struct()]
  def list(module) do
    Repo.all(module)
  end

  @doc """
  Returns all records for the given module/schema with custom ordering.

  ## Examples
      iex> ServiceUtils.list_ordered(MyApp.User, [asc: :name])
      [%MyApp.User{}, ...]
  """
  @spec list_ordered(module(), keyword()) :: [struct()]
  def list_ordered(module, order_by) do
    module
    |> order_by(^order_by)
    |> Repo.all()
  end

  @doc """
  Returns paginated records for the given module/schema.

  ## Examples
      iex> ServiceUtils.list_paginated(MyApp.User, page: 1, per_page: 10)
      [%MyApp.User{}, ...]
  """
  @spec list_paginated(module(), keyword()) :: [struct()]
  def list_paginated(module, opts \\ []) do
    page = Keyword.get(opts, :page)
    per_page = Keyword.get(opts, :per_page)
    order_by = Keyword.get(opts, :order_by, asc: :id)

    base_query = from(m in module, order_by: ^order_by)

    case {page, per_page} do
      {p, pp} when is_integer(p) and p > 0 and is_integer(pp) and pp > 0 ->
        offset = (p - 1) * pp

        base_query
        |> limit(^pp)
        |> offset(^offset)
        |> Repo.all()

      _ ->
        Repo.all(base_query)
    end
  end

  @doc """
  Retrieves a record by its primary key.

  Returns `nil` if no record is found.

  ## Examples
      iex> ServiceUtils.get(MyApp.User, 123)
      %MyApp.User{id: 123}

      iex> ServiceUtils.get(MyApp.User, 999)
      nil
  """
  @spec get(module(), term()) :: struct() | nil
  def get(module, id) do
    Repo.get(module, id)
  end

  @doc """
  Retrieves a record by its primary key.

  Raises `Ecto.NoResultsError` if no record is found.

  ## Examples
      iex> ServiceUtils.get!(MyApp.User, 123)
      %MyApp.User{id: 123}

      iex> ServiceUtils.get!(MyApp.User, 999)
      ** (Ecto.NoResultsError)
  """
  @spec get!(module(), term()) :: struct()
  def get!(module, id) do
    Repo.get!(module, id)
  end

  @doc """
  Retrieves a record by its primary key with preloaded associations.

  ## Examples
      iex> ServiceUtils.get_with_preload!(MyApp.User, 123, [:posts, :comments])
      %MyApp.User{id: 123, posts: [...], comments: [...]}
  """
  @spec get_with_preload!(module(), term(), list()) :: struct()
  def get_with_preload!(module, id, preloads) do
    module
    |> Repo.get!(id)
    |> Repo.preload(preloads)
  end

  @doc """
  Retrieves a record by its primary key with preloaded associations.

  Returns `nil` if no record is found.
  """
  @spec get_with_preload(module(), term(), list()) :: struct() | nil
  def get_with_preload(module, id, preloads) do
    case Repo.get(module, id) do
      nil -> nil
      record -> Repo.preload(record, preloads)
    end
  end

  @doc """
  Retrieves a record matching the given attributes.

  Returns `nil` if no record is found.

  ## Examples
      iex> ServiceUtils.get_by(MyApp.User, %{email: "user@example.com"})
      %MyApp.User{email: "user@example.com"}

      iex> ServiceUtils.get_by(MyApp.User, email: "user@example.com")
      %MyApp.User{email: "user@example.com"}
  """
  @spec get_by(module(), keyword() | map()) :: struct() | nil
  def get_by(module, args) do
    Repo.get_by(module, args)
  end

  @doc """
  Retrieves a record matching the given attributes.

  Raises `Ecto.NoResultsError` if no record is found.

  ## Examples
      iex> ServiceUtils.get_by!(MyApp.User, %{email: "user@example.com"})
      %MyApp.User{email: "user@example.com"}

      iex> ServiceUtils.get_by!(MyApp.User, %{email: "nonexistent@example.com"})
      ** (Ecto.NoResultsError)
  """
  @spec get_by!(module(), keyword() | map()) :: struct()
  def get_by!(module, args) do
    Repo.get_by!(module, args)
  end

  @doc """
  Creates a new record with the given attributes.

  The module must implement a `changeset/2` function.

  Returns `{:ok, struct}` on success or `{:error, changeset}` on failure.

  ## Examples
      iex> ServiceUtils.create(MyApp.User, %{name: "John", email: "john@example.com"})
      {:ok, %MyApp.User{name: "John", email: "john@example.com"}}

      iex> ServiceUtils.create(MyApp.User, %{email: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  @spec create(module(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def create(module, attrs \\ %{}) do
    struct(module)
    |> module.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing record with the given attributes.

  The module must implement a `changeset/2` function.

  Returns `{:ok, struct}` on success or `{:error, changeset}` on failure.

  ## Examples
      iex> ServiceUtils.update(user, %{name: "Jane"})
      {:ok, %MyApp.User{name: "Jane"}}

      iex> ServiceUtils.update(user, %{email: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  @spec update(struct(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def update(record, attrs) do
    module = record.__struct__

    record
    |> module.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes the given record.

  Returns `{:ok, struct}` on success or `{:error, changeset}` on failure.

  ## Examples
      iex> ServiceUtils.delete(user)
      {:ok, %MyApp.User{}}

      iex> ServiceUtils.delete(record_with_constraints)
      {:error, %Ecto.Changeset{}}
  """
  @spec delete(struct()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def delete(record) do
    Repo.delete(record)
  end

  @doc """
  Returns an `Ecto.Changeset` for tracking changes to a record.

  The module must implement a `changeset/2` function.

  ## Examples
      iex> ServiceUtils.change(user, %{name: "New Name"})
      %Ecto.Changeset{data: %MyApp.User{}, changes: %{name: "New Name"}}
  """
  @spec change(struct(), map()) :: Ecto.Changeset.t()
  def change(record, attrs \\ %{}) do
    module = record.__struct__
    module.changeset(record, attrs)
  end

  @doc """
  Counts the total number of records for the given module.

  ## Examples
      iex> ServiceUtils.count(MyApp.User)
      42
  """
  @spec count(module()) :: non_neg_integer()
  def count(module) do
    Repo.aggregate(module, :count)
  end

  @doc """
  Checks if a record exists with the given attributes.

  ## Examples
      iex> ServiceUtils.exists?(MyApp.User, %{email: "user@example.com"})
      true

      iex> ServiceUtils.exists?(MyApp.User, %{email: "nonexistent@example.com"})
      false
  """
  @spec exists?(module(), keyword() | map()) :: boolean()
  def exists?(module, args) do
    module
    |> where(^Enum.to_list(args))
    |> Repo.exists?()
  end

  @doc """
  Lists records with a specific condition using a where clause.

  ## Examples
      iex> ServiceUtils.list_where(MyApp.User, [active: true])
      [%MyApp.User{active: true}, ...]

      iex> ServiceUtils.list_where(MyApp.Post, [status: "published"], order_by: [desc: :inserted_at])
      [%MyApp.Post{status: "published"}, ...]
  """
  @spec list_where(module(), keyword() | map(), keyword()) :: [struct()]
  def list_where(module, conditions, opts \\ []) do
    order_by = Keyword.get(opts, :order_by, asc: :id)

    module
    |> where(^Enum.to_list(conditions))
    |> order_by(^order_by)
    |> Repo.all()
  end

  @doc """
  Executes a custom query function on the module.

  Useful for complex queries that don't fit the standard patterns.

  ## Examples
      iex> query_fn = fn query -> where(query, [u], u.age > 18) end
      iex> ServiceUtils.list_with_query(MyApp.User, query_fn)
      [%MyApp.User{age: 25}, ...]
  """
  @spec list_with_query(module(), function()) :: [struct()]
  def list_with_query(module, query_fn) when is_function(query_fn, 1) do
    module
    |> query_fn.()
    |> Repo.all()
  end
end
