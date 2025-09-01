defmodule Phoexnip.UserRolesService do
  @moduledoc """
  Provides functions to manage user-role associations, fetch roles for a user,
  and retrieve the highest permissions based on user roles and sitemap entries.
  """

  import Ecto.Query, warn: false
  alias Phoexnip.{Repo, SitemapService, RolesPermission, UserRoles, Roles}

  @doc """
  Returns all user-role associations.

  ## Examples
      iex> Phoexnip.UserRolesService.list(%{})
      [%Phoexnip.UserRoles{}, ...]
  """
  @spec list(params :: map()) :: [UserRoles.t()]
  def list(_params) do
    Repo.all(UserRoles)
  end

  @doc """
  Fetches all roles that a given user belongs to (where `belongs_in_role` is true),
  preloading each role's permissions.

  ## Examples
      iex> Phoexnip.UserRolesService.fetch_roles_users_belongs_too(user)
      [%Phoexnip.Roles{role_permissions: [...]}, ...]
  """
  @spec fetch_roles_users_belongs_too(user :: struct()) :: [Roles.t()]
  def fetch_roles_users_belongs_too(user) do
    from(r in Roles,
      join: ur in UserRoles,
      on: ur.role_id == r.id,
      where: ur.user_id == ^user.id and ur.belongs_in_role == true,
      select: r
    )
    |> Repo.all()
    |> Repo.preload(:role_permissions)
  end

  @doc """
  Retrieves the highest permission entries for each sitemap code,
  returning a list of `%RolesPermission{}` structs sorted by sequence.

  - If the user is a super user, all sitemap entries are converted into permissions with default level.
  - Otherwise, permissions are gathered from the user's roles.
  """
  @spec fetch_highest_permission_for_users(user :: struct()) :: [RolesPermission.t()]
  def fetch_highest_permission_for_users(user) do
    if user.super_user do
      sitemap_entries = SitemapService.list() |> Enum.sort_by(& &1.sequence)

      Enum.map(sitemap_entries, fn entry ->
        %RolesPermission{
          permission: 16,
          sitemap_code: entry.code,
          sitemap_name: entry.displayname,
          sitemap_level: entry.level,
          sitemap_parent: entry.parent,
          sitemap_url: entry.url,
          sequence: entry.sequence
        }
      end)
    else
      user_roles = fetch_roles_users_belongs_too(user)
      all_role_permissions = Enum.flat_map(user_roles, fn role -> role.role_permissions end)

      all_role_permissions
      |> Enum.group_by(& &1.sitemap_code)
      |> Enum.map(fn {_code, entries} ->
        Enum.max_by(entries, & &1.permission)
      end)
      |> Enum.sort_by(& &1.sequence)
    end
  end

  @doc """
  Builds a menu-like structure of user permissions grouped by level 0 and their children,
  based on the highest permission per sitemap code.

  - For super users, includes all sitemap entries.
  - For regular users, derives permissions from assigned roles.
  """
  @spec fetch_user_permissions(user :: struct()) :: list(map() | RolesPermission.t())
  def fetch_user_permissions(user) do
    if user.super_user do
      sitemap_entries = SitemapService.list() |> Enum.sort_by(& &1.sequence)

      all_role_permissions =
        Enum.map(sitemap_entries, fn entry ->
          %RolesPermission{
            permission: 16,
            sitemap_code: entry.code,
            sitemap_name: entry.displayname,
            sitemap_level: entry.level,
            sitemap_parent: entry.parent,
            sitemap_description: entry.description,
            sitemap_url: entry.url,
            sequence: entry.sequence
          }
        end)

      highest_permission_per_code =
        all_role_permissions
        |> Enum.group_by(& &1.sitemap_code)
        |> Enum.map(fn {_code, entries} ->
          Enum.max_by(entries, & &1.permission)
        end)

      highest_permission_per_code
      |> Enum.filter(fn %RolesPermission{sitemap_level: lvl} -> lvl == 0 end)
      |> Enum.map(fn %RolesPermission{sitemap_code: code} = level0 ->
        children =
          highest_permission_per_code
          |> Enum.filter(fn %RolesPermission{sitemap_parent: parent, sitemap_level: lvl} ->
            lvl == 1 and parent == code
          end)

        %{
          permission: level0.permission,
          sitemap_code: level0.sitemap_code,
          sitemap_parent: level0.sitemap_parent,
          sitemap_level: level0.sitemap_level,
          sitemap_description: level0.sitemap_description,
          sitemap_name: level0.sitemap_name,
          sitemap_url: level0.sitemap_url,
          sequence: level0.sequence,
          children: Enum.sort_by(children, & &1.sequence)
        }
      end)
      |> Enum.sort_by(& &1.sequence)
    else
      user_roles = fetch_roles_users_belongs_too(user)
      all_role_permissions = Enum.flat_map(user_roles, fn role -> role.role_permissions end)

      highest_permission_per_code =
        all_role_permissions
        |> Enum.group_by(& &1.sitemap_code)
        |> Enum.map(fn {_code, entries} ->
          Enum.max_by(entries, & &1.permission)
        end)

      highest_permission_per_code
      |> Enum.filter(fn %RolesPermission{sitemap_level: lvl} -> lvl == 0 end)
      |> Enum.map(fn %RolesPermission{sitemap_code: code} = level0 ->
        children =
          highest_permission_per_code
          |> Enum.filter(fn %RolesPermission{sitemap_parent: parent, sitemap_level: lvl} ->
            lvl == 1 and parent == code
          end)

        %{
          permission: level0.permission,
          sitemap_code: level0.sitemap_code,
          sitemap_parent: level0.sitemap_parent,
          sitemap_description: level0.sitemap_description,
          sitemap_level: level0.sitemap_level,
          sitemap_name: level0.sitemap_name,
          sitemap_url: level0.sitemap_url,
          sequence: level0.sequence,
          children: Enum.sort_by(children, & &1.sequence)
        }
      end)
      |> Enum.sort_by(& &1.sequence)
    end
  end

  @doc """
  Retrieves level-two permissions under a specified parent code.

  - For super users, includes all matching sitemap entries.
  - For regular users, filters permissions from assigned roles.
  """
  @spec fetch_level_two_user_permissions(user :: struct(), parent :: String.t()) :: [
          RolesPermission.t()
        ]
  def fetch_level_two_user_permissions(user, parent) do
    if user.super_user do
      sitemap_entries = SitemapService.list()

      sitemap_entries
      |> Enum.map(fn entry ->
        %RolesPermission{
          permission: 16,
          sitemap_code: entry.code,
          sitemap_name: entry.displayname,
          sitemap_level: entry.level,
          sitemap_parent: entry.parent,
          sitemap_description: entry.description,
          sitemap_url: entry.url
        }
      end)
      |> Enum.filter(fn rp -> rp.sitemap_level == 2 and rp.sitemap_parent == parent end)
      |> Enum.group_by(& &1.sitemap_code)
      |> Enum.map(fn {_code, entries} -> Enum.max_by(entries, & &1.permission) end)
      |> Enum.filter(&(&1.permission > 0))
      |> Enum.sort_by(& &1.sequence)
    else
      fetch_roles_users_belongs_too(user)
      |> Enum.flat_map(& &1.role_permissions)
      |> Enum.filter(fn rp -> rp.sitemap_level == 2 and rp.sitemap_parent == parent end)
      |> Enum.group_by(& &1.sitemap_code)
      |> Enum.map(fn {_code, entries} -> Enum.max_by(entries, & &1.permission) end)
      |> Enum.filter(&(&1.permission > 0))
      |> Enum.sort_by(& &1.sequence)
    end
  end

  @doc """
  Retrieves a `%UserRoles{}` by its ID or raises if not found.
  """
  @spec get!(id :: integer()) :: UserRoles.t()
  def get!(id), do: Repo.get!(UserRoles, id)

  @doc """
  Retrieves a `%UserRoles{}` by its ID or returns `nil` if not found.
  """
  @spec get(id :: integer()) :: UserRoles.t() | nil
  def get(id), do: Repo.get(UserRoles, id)

  @doc """
  Retrieves a `%UserRoles{}` matching the given clauses or raises if not found.
  """
  @spec get_by!(clauses :: Keyword.t() | map()) :: UserRoles.t()
  def get_by!(args), do: Repo.get_by!(UserRoles, args)

  @doc """
  Retrieves a `%UserRoles{}` matching the given clauses or returns `nil` if not found.
  """
  @spec get_by(clauses :: Keyword.t() | map()) :: UserRoles.t() | nil
  def get_by(args), do: Repo.get_by(UserRoles, args)

  @doc """
  Creates a new `%UserRoles{}` with the given attributes.

  Returns `{:ok, user_role}` or `{:error, changeset}`.
  """
  @spec create(attrs :: map()) :: {:ok, UserRoles.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %UserRoles{}
    |> UserRoles.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a `%UserRoles{}` with the given attributes.

  Returns `{:ok, user_role}` or `{:error, changeset}`.
  """
  @spec update(attrs :: map()) :: {:ok, UserRoles.t()} | {:error, Ecto.Changeset.t()}
  def update(attrs \\ %{}) do
    %UserRoles{}
    |> UserRoles.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes the given `%UserRoles{}`.

  Returns `{:ok, user_role}` or `{:error, changeset}`.
  """
  @spec delete(role :: UserRoles.t()) :: {:ok, UserRoles.t()} | {:error, Ecto.Changeset.t()}
  def delete(%UserRoles{} = role) do
    Repo.delete(role)
  end
end
