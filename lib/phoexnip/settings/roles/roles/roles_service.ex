defmodule Phoexnip.RolesService do
  @moduledoc """
  Provides an API for managing `Roles` entities in the system.
  Supports listing (with pagination and optional preloads), fetching, creating,
  updating, deleting, and counting roles.
  """

  import Ecto.Query, warn: false
  alias Phoexnip.{Repo, Roles}
  alias Phoexnip.RolesPermission

  @doc """
  Lists roles according to the given options.

  ## Options

    * `:page` — (positive integer) which page to fetch
    * `:per_page` — (positive integer) how many items per page
    * `:preload` — (boolean) whether to preload `:role_permissions` (default `false`)

  Returns a list of `%Roles{}` structs, preloaded if requested.
  """
  @spec list(opts :: keyword()) :: [Roles.t()]
  def list(opts \\ []) when is_list(opts) do
    page = Keyword.get(opts, :page)
    per_page = Keyword.get(opts, :per_page)
    preload? = Keyword.get(opts, :preload, false)

    base_query = from(r in Roles, order_by: [asc: r.id])

    query =
      case {page, per_page} do
        {p, pp} when is_integer(p) and p > 0 and is_integer(pp) and pp > 0 ->
          offset = (p - 1) * pp

          base_query
          |> limit(^pp)
          |> offset(^offset)

        _ ->
          base_query
      end

    roles = Repo.all(query)

    if preload? do
      Repo.preload(roles, role_permissions: from(rp in RolesPermission, order_by: rp.id))
    else
      roles
    end
  end

  @doc """
  Fetches a role by its `id`.
  Raises `Ecto.NoResultsError` if no role is found.
  """
  @spec get!(id :: integer()) :: Roles.t()
  def get!(id) do
    Roles
    |> Repo.get!(id)
    |> Repo.preload(role_permissions: from(rp in RolesPermission, order_by: rp.id))
  end

  @doc """
  Fetches a role by its `id`.
  Returns `nil` if no role is found.
  """
  @spec get(id :: integer()) :: Roles.t() | nil
  def get(id) do
    Roles
    |> Repo.get(id)
    |> Repo.preload(role_permissions: from(rp in RolesPermission, order_by: rp.id))
  end

  @doc """
  Fetches a role by fields matching `args`.
  Raises `Ecto.NoResultsError` if no matching role is found.
  """
  @spec get_by!(args :: keyword()) :: Roles.t()
  def get_by!(args) when is_list(args) do
    Repo.get_by!(Roles, args)
  end

  @doc """
  Creates a new role with the given attributes.

  Returns `{:ok, %Roles{}}` on success or `{:error, changeset}` on failure.
  """
  @spec create(attrs :: map()) :: {:ok, Roles.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) when is_map(attrs) do
    %Roles{}
    |> Roles.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing role with the given attributes.

  Returns `{:ok, %Roles{}}` on success or `{:error, changeset}` on failure.
  """
  @spec update(role :: Roles.t(), attrs :: map()) ::
          {:ok, Roles.t()} | {:error, Ecto.Changeset.t()}
  def update(%Roles{} = role, attrs \\ %{}) when is_map(attrs) do
    role
    |> Roles.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking role changes.
  """
  @spec change(role :: Roles.t(), attrs :: map()) :: Ecto.Changeset.t()
  def change(%Roles{} = role, attrs \\ %{}) when is_map(attrs) do
    Roles.changeset(role, attrs)
  end

  @doc """
  Deletes the given role.

  Returns `{:ok, %Roles{}}` on success or `{:error, changeset}` on failure.
  """
  @spec delete(role :: Roles.t()) :: {:ok, Roles.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Roles{} = role) do
    Repo.delete(role)
  end
end
