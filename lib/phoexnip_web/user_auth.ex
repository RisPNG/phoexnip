defmodule PhoexnipWeb.UserAuth do
  use PhoexnipWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Phoexnip.Users.UserService
  alias Phoexnip.UserRolesService

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_phoexnip_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = UserService.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)
    # 12 hours
    expiry_time = DateTime.utc_now() |> DateTime.add(43200, :second) |> DateTime.to_unix()

    redirect_path = role_redirect_path(user)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> put_session(:session_expiry, expiry_time)
    |> redirect(to: user_return_to || redirect_path)
  end

  defp role_redirect_path(user) do
    sitemap = Phoexnip.UserRolesService.fetch_user_permissions(user)

    home =
      Enum.find(sitemap, fn p -> p.sitemap_code == "H" and Map.get(p, :permission, 0) > 0 end)

    cond do
      home ->
        # both exist, go to root
        "/"

      home ->
        if is_binary(home.sitemap_url) and home.sitemap_url != "" do
          "/" <> home.sitemap_url
        else
          "/"
        end

      true ->
        # fallback
        "/"
    end
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && UserService.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      PhoexnipWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && UserService.get_user_by_session_token(user_token)

    conn =
      if user do
        permissions = UserRolesService.fetch_user_permissions(user)
        conn |> put_session(:permission, permissions)

        assign(conn, :permissions, permissions)
      else
        conn
      end

    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule PhoexnipWeb.PageLive do
        use PhoexnipWeb, :live_view

        on_mount {PhoexnipWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{PhoexnipWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    socket = Phoenix.Component.assign(socket, :breadcrumb_first_segment, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_second_segment, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_second_link, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_third_segment, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_third_link, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_fourth_segment, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_help_link, nil)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    socket = Phoenix.Component.assign(socket, :breadcrumb_first_segment, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_second_segment, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_second_link, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_third_segment, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_fourth_segment, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_third_link, nil)
    socket = Phoenix.Component.assign(socket, :breadcrumb_help_link, nil)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    socket =
      Phoenix.Component.assign_new(socket, :current_user, fn ->
        if user_token = session["user_token"] do
          UserService.get_user_by_session_token(user_token)
        end
      end)

    Phoenix.Component.assign_new(socket, :permissions, fn ->
      if current_user = socket.assigns[:current_user] do
        # Assuming you have a function to fetch permissions based on the user
        UserRolesService.fetch_user_permissions(current_user)
      else
        # Return default or empty permissions if no current_user is found
        []
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  def find_permission(permissions, code) do
    Enum.find_value(permissions, fn permission ->
      if get_sitemap_code(permission) == code do
        permission
      else
        children = get_children(permission)
        find_in_children(children, code)
      end
    end)
  end

  defp find_in_children(children, code) do
    Enum.find_value(children, fn child ->
      if get_sitemap_code(child) == code do
        child
      else
        find_in_children(get_children(child), code)
      end
    end)
  end

  defp get_sitemap_code(%{sitemap_code: sitemap_code}), do: sitemap_code

  defp get_children(%{children: children}), do: children
  defp get_children(_), do: []

  defp signed_in_path(_conn), do: ~p"/"
end
