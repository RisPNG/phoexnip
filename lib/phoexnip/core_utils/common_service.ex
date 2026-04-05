defmodule Phoexnip.CoreUtils.CommonService do
  @moduledoc """
  Generic service utilities for common CRUD operations across entity types.

  This module centralizes shared database access patterns so feature-specific
  services can focus on business rules.
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo

  @spec list(module()) :: [struct()]
  def list(module) do
    Repo.all(module)
  end

  @spec list_ordered(module(), keyword()) :: [struct()]
  def list_ordered(module, order_by) do
    module
    |> order_by(^order_by)
    |> Repo.all()
  end

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

  @spec get(module(), term()) :: struct() | nil
  def get(module, id) do
    Repo.get(module, id)
  end

  @spec get!(module(), term()) :: struct()
  def get!(module, id) do
    Repo.get!(module, id)
  end

  @spec get_with_preload!(module(), term(), list()) :: struct()
  def get_with_preload!(module, id, preloads) do
    module
    |> Repo.get!(id)
    |> Repo.preload(preloads)
  end

  @spec get_with_preload(module(), term(), list()) :: struct() | nil
  def get_with_preload(module, id, preloads) do
    case Repo.get(module, id) do
      nil -> nil
      record -> Repo.preload(record, preloads)
    end
  end

  @spec get_by(module(), keyword() | map()) :: struct() | nil
  def get_by(module, args) do
    Repo.get_by(module, args)
  end

  @spec get_by!(module(), keyword() | map()) :: struct()
  def get_by!(module, args) do
    Repo.get_by!(module, args)
  end

  @spec create(module(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def create(module, attrs \\ %{}) do
    struct(module)
    |> module.changeset(attrs)
    |> Repo.insert()
  end

  @spec update(struct(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def update(record, attrs) do
    module = record.__struct__

    record
    |> module.changeset(attrs)
    |> Repo.update()
  end

  @spec delete(struct()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def delete(record) do
    Repo.delete(record)
  end

  @spec change(struct(), map()) :: Ecto.Changeset.t()
  def change(record, attrs \\ %{}) do
    module = record.__struct__
    module.changeset(record, attrs)
  end

  @spec count(module()) :: non_neg_integer()
  def count(module) do
    Repo.aggregate(module, :count)
  end

  @spec exists?(module(), keyword() | map()) :: boolean()
  def exists?(module, args) do
    module
    |> where(^Enum.to_list(args))
    |> Repo.exists?()
  end

  @spec list_where(module(), keyword() | map(), keyword()) :: [struct()]
  def list_where(module, conditions, opts \\ []) do
    order_by = Keyword.get(opts, :order_by, asc: :id)

    module
    |> where(^Enum.to_list(conditions))
    |> order_by(^order_by)
    |> Repo.all()
  end

  @spec list_with_query(module(), function()) :: [struct()]
  def list_with_query(module, query_fn) when is_function(query_fn, 1) do
    module
    |> query_fn.()
    |> Repo.all()
  end
end
