defmodule PhoexnipWeb.RolesJSON do
  @moduledoc """
  Serializes `Roles` structs and their associated `RolesPermission` records into
  maps suitable for JSON encoding in API responses.

  This module provides two rendering functions:

    * `index/1` – renders a list of roles.
    * `show/1` – renders a single role.

  Both functions return a map with a `:data` key containing the serialized result.
  """

  alias Phoexnip.RolesPermission
  alias Phoexnip.Roles

  @doc """
  Renders a list of roles as a JSON-serializable map.

  ## Parameters

    - `%{roles: roles}`: a map with the key `:roles` pointing to a list of `Roles` structs.

  ## Returns

    - A map with `:data` holding a list of serialized role maps.

  ## Example

      iex> index(%{roles: [role1, role2]})
      %{data: [%{id: 1, name: "Admin", …}, %{id: 2, name: "User", …}]}
  """
  @spec index(%{roles: [Roles.t()]}) :: %{data: [map()]}
  def index(%{roles: roles}) do
    %{data: for(role <- roles, do: data(role))}
  end

  @doc """
  Renders a single role as a JSON-serializable map.

  ## Parameters

    - `%{role: role}`: a map with the key `:role` pointing to a `Roles` struct.

  ## Returns

    - A map with `:data` holding the serialized role map.

  ## Example

      iex> show(%{role: role})
      %{data: %{id: 1, name: "Admin", …}}
  """
  @spec show(%{role: Roles.t()}) :: %{data: map()}
  def show(%{role: role}) do
    %{data: data(role)}
  end

  @doc false
  @spec data(Roles.t()) :: map()
  defp data(%Roles{} = role) do
    %{
      id: role.id,
      description: role.description,
      name: role.name,
      role_permissions:
        case role.role_permissions do
          %Ecto.Association.NotLoaded{} ->
            []

          permissions when is_list(permissions) ->
            Enum.map(permissions, &data_permissions/1)
        end
    }
  end

  @doc false
  @spec data_permissions(RolesPermission.t()) :: map()
  defp data_permissions(%RolesPermission{} = permissions) do
    %{
      id: permissions.id,
      permission: permissions.permission,
      role_id: permissions.role_id,
      sitemap_code: permissions.sitemap_code,
      sitemap_name: permissions.sitemap_name,
      sitemap_level: permissions.sitemap_level,
      sitemap_parent: permissions.sitemap_parent,
      sitemap_url: permissions.sitemap_url,
      sequence: permissions.sequence
    }
  end
end
