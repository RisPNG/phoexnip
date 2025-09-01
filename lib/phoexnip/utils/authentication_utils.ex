defmodule Phoexnip.AuthenticationUtils do
  @moduledoc """
  A collection of helpers for enforcing and checking user permissions in both
  LiveView sockets and API endpoints.

  ## LiveView Authorization

    * `check_page_permissions/3`
      Grants or denies page access in a LiveView socket based on the user’s
      `:super_user` flag or their permissions list. Redirects or sets an error
      flash when access is denied.

    * `check_level_two_permissions/4`
      Similar to `check_page_permissions/3` but fetches “level two” permissions
      for secondary authorization contexts.

  ## API Authorization

    * `check_api_permissions/3`
      Returns `true` or `false` for API endpoint access by a Plug connection,
      checking `:super_user` or the user’s assigned permissions.

    * `check_api_permissions_level_two/3`
      Returns `true` or `false` after fetching “level two” permissions for
      API access scenarios.


  ## Routing & Integration
  - Relies on assigns:
    - `:current_user` (must include `:super_user` boolean)
    - `:permissions` list (maps or structs with `:sitemap_code` and `:permission`)

  These utilities centralize permission logic across LiveView and API layers,
  ensuring consistent behavior and redirects/flashes when access is denied.
  """
  use Phoenix.VerifiedRoutes,
    endpoint: PhoexnipWeb.Endpoint,
    router: PhoexnipWeb.Router

  use Phoenix.LiveView

  @doc """
  Checks the current user's permission for the given `page_code`, assigning
  a `:permission_level` on the socket or redirecting/setting an error flash if access is denied.

  - If the current user is a super user, grants the highest permission level (`16`).
  - Otherwise, looks up the user's permission via `check_permissions/2`.
    - If no permission is found or the user's level is below `permission_needed`, redirects based on `permission.sitemap_code`:
      - `"H"`     → redirect to `"/kiosk"`
      - `"KIOSK"` → redirect to `"/"`
      - _any other_ → set an error flash `"You do not have access to this page."` and redirect to `"/"`
    - If the user's level meets or exceeds `permission_needed`, assigns `:permission_level` to that value.

  ## Examples

      iex> socket = assign(socket, :current_user, %{super_user: true})
      iex> check_page_permissions(socket, "any_page", 5)
      #=> socket with assigns.permission_level == 16

      iex> perms = [%{sitemap_code: "X", permission: 4}]
      iex> socket = socket |> assign(:current_user, %{super_user: false}) |> assign(:permissions, perms)
      iex> check_page_permissions(socket, "X", 5)
      #=> redirected with error flash to "/"

      iex> perms = [%{sitemap_code: "Y", permission: 10}]
      iex> socket = socket |> assign(:current_user, %{super_user: false}) |> assign(:permissions, perms)
      iex> check_page_permissions(socket, "Y", 5)
      #=> socket with assigns.permission_level == 10
  """
  @spec check_page_permissions(
          socket :: Phoenix.LiveView.Socket.t(),
          page_code :: String.t() | atom(),
          permission_needed :: non_neg_integer()
        ) :: Phoenix.LiveView.Socket.t()
  def check_page_permissions(socket, page_code, permission_needed) do
    if socket.assigns.current_user.super_user do
      socket |> assign(permission_level: 16)
    else
      permission = check_permissions(socket.assigns.permissions, page_code)

      if permission == nil || permission.permission < permission_needed do
        case permission.sitemap_code do
          "H" ->
            socket
            |> redirect(to: ~p"/")

          _ ->
            socket
            |> put_flash(:error, "You do not have access to this page.")
            |> redirect(to: ~p"/")
        end
      else
        socket |> assign(permission_level: permission.permission)
      end
    end
  end

  @doc """
  Determines whether the current API user (in the given `conn`) has at least the required permission for `page_code`.

  Returns `true` if:
    - the user is a super user (`current_user.super_user`), or
    - the user has an entry for `page_code` whose `permission` value is greater than or equal to `permission_needed`

  Otherwise returns `false`.

  ## Parameters

    * `conn` — a Plug connection struct with assigns:
      - `:current_user` (must include boolean `:super_user`)
      - `:permissions` (a list or map passed to `check_permissions/2`)
    * `page_code` — an identifier (string or atom) for the page whose permissions to check
    * `permission_needed` — the minimum permission level required (non-negative integer)

  ## Returns

    * `true` if the user may access the API endpoint
    * `false` if the user lacks sufficient permission

  ## Examples

      iex> conn = assign(%Plug.Conn{}, :current_user, %{super_user: true})
      iex> check_api_permissions(conn, "dashboard", 5)
      true

      iex> perms = [%{sitemap_code: "X", permission: 4}]
      iex> conn = conn |> assign(:current_user, %{super_user: false}) |> assign(:permissions, perms)
      iex> check_api_permissions(conn, "X", 5)
      false

      iex> perms = [%{sitemap_code: :reports, permission: 10}]
      iex> conn = conn |> assign(:current_user, %{super_user: false}) |> assign(:permissions, perms)
      iex> check_api_permissions(conn, :reports, 5)
      true
  """
  @spec check_api_permissions(
          conn :: Plug.Conn.t(),
          page_code :: String.t() | atom(),
          permission_needed :: non_neg_integer()
        ) :: boolean()
  def check_api_permissions(conn, page_code, permission_needed) do
    if conn.assigns.current_user.super_user do
      true
    else
      permission = check_permissions(conn.assigns.permissions, page_code)

      if permission == nil || permission.permission < permission_needed do
        false
      else
        true
      end
    end
  end

  @doc """
  Determines whether a level-two user has sufficient permission for the given `page_code`.

  First grants access if the user is a super user. Otherwise it:

    1. Fetches level-two permissions via
       `Phoexnip.UserRolesService.fetch_level_two_user_permissions(user, "SET3")`
    2. Finds the entry for `page_code` using `check_permissions/2`.
    3. Returns `true` if that permission’s `:permission` value is ≥ `permissions_needed`; otherwise `false`.

  ## Parameters

    * `user` – a struct with a boolean `:super_user` field
    * `page_code` – identifier (string or atom) for the page
    * `permissions_needed` – the minimum permission level required (non-negative integer)

  ## Returns

    * `true` if the user is super user or has sufficient level-two permission
    * `false` otherwise

  ## Examples

      iex> user = %User{super_user: true}
      iex> check_api_permissions_level_two(user, "dashboard", 5)
      true

      iex> user = %User{super_user: false}
      iex> # suppose fetch_level_two_user_permissions(user, "SET3") returns [%{sitemap_code: "reports", permission: 4}]
      iex> check_api_permissions_level_two(user, "reports", 5)
      false

      iex> user = %User{super_user: false}
      iex> # suppose the permission for :reports is now %{permission: 10}
      iex> check_api_permissions_level_two(user, "reports", 5)
      true
  """
  @spec check_api_permissions_level_two(
          user :: struct(),
          page_code :: String.t() | atom(),
          permissions_needed :: non_neg_integer()
        ) :: boolean()
  def check_api_permissions_level_two(user, page_code, permissions_needed) do
    permissions = Phoexnip.UserRolesService.fetch_level_two_user_permissions(user, "SET3")

    if user.super_user do
      true
    else
      permission = check_permissions(permissions, page_code)

      if permission == nil || permission.permission < permissions_needed do
        false
      else
        true
      end
    end
  end

  @doc """
  Ensures that a level-two user has the required permission for the given `page_code` in a LiveView socket.

  - If the current user is a super user, assigns `:permission_level` to `16`.
  - Otherwise, looks up the permission in the provided `permissions` list via `check_permissions/2`:
    - If no permission is found or is below `permission_needed`, sets an error flash `"You do not have access to this page."` and redirects to `"/"`.
    - If the permission meets or exceeds `permission_needed`, assigns `:permission_level` to that value.

  ## Parameters

    * `socket`            — a `Phoenix.LiveView.Socket` struct with `assigns.current_user`
    * `permissions`       — a list of permission structs or maps
    * `page_code`         — the page identifier (string or atom)
    * `permission_needed` — minimum permission level required (non-negative integer)

  ## Returns

    * the updated `socket`, either with a new `:permission_level` assign or redirected with an error flash

  ## Examples

      iex> socket = assign(socket, :current_user, %{super_user: true})
      iex> check_level_two_permissions(socket, [], :dashboard, 5)
      #=> socket with assigns.permission_level == 16

      iex> perms = [%{sitemap_code: "reports", permission: 4}]
      iex> socket = socket |> assign(:current_user, %{super_user: false})
      iex> check_level_two_permissions(socket, perms, "reports", 5)
      #=> socket redirected with error flash to "/"

      iex> perms = [%{sitemap_code: "reports", permission: 10}]
      iex> socket = socket |> assign(:current_user, %{super_user: false})
      iex> check_level_two_permissions(socket, perms, :reports, 5)
      #=> socket with assigns.permission_level == 10
  """
  @spec check_level_two_permissions(
          socket :: Phoenix.LiveView.Socket.t(),
          permissions :: [map()],
          page_code :: String.t() | atom(),
          permission_needed :: non_neg_integer()
        ) :: Phoenix.LiveView.Socket.t()
  def check_level_two_permissions(socket, permissions, page_code, permission_needed) do
    if socket.assigns.current_user.super_user do
      socket |> assign(permission_level: 16)
    else
      permission = check_permissions(permissions, page_code)

      if permission == nil || permission.permission < permission_needed do
        socket
        |> put_flash(:error, "You do not have access to this page.")
        |> redirect(to: ~p"/")
      else
        socket |> assign(permission_level: permission.permission)
      end
    end
  end

  @doc """
  Looks up a permission entry for the given `page_code` from the list of `permissions`.

  ## Parameters

    * `permissions` – a list of permission structs or maps, each expected to have at least
      a `:sitemap_code` (string or atom) and a `:permission` (integer) field
    * `page_code`   – the sitemap code (string or atom) to match against each permission

  ## Returns

    * the matching permission struct/map if found
    * `nil` if no matching entry exists

  ## Examples

      iex> perms = [%{sitemap_code: "dashboard", permission: 5}, %{sitemap_code: "reports", permission: 2}]
      iex> check_permissions(perms, "dashboard")
      %{sitemap_code: "dashboard", permission: 5}

      iex> check_permissions(perms, :settings)
      nil
  """
  @spec check_permissions(
          permissions :: [map()],
          page_code :: String.t() | atom()
        ) :: map() | nil
  def check_permissions(permissions, page_code) do
    PhoexnipWeb.UserAuth.find_permission(permissions, page_code)
  end
end
