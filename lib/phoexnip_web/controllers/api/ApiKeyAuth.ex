defmodule PhoexnipWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  A Plug to authenticate API requests using an X-API-Key header.

  This plug:
    1. Reads the "x-api-key" header from the request.
    2. Attempts to fetch user and permission data from the ApiKeyCache.
    3. If not cached, retrieves the API key record from the database via `Phoexnip.ServiceUtils` and `Phoexnip.Settings.ApiKey`,
       validates its expiry, loads the associated user and permissions, and stores them in the cache.
    4. Assigns `:current_user` and `:permissions` into `conn.assigns` on success.
    5. Returns a `401 Unauthorized` on missing or invalid keys, or `403 Forbidden` on expired keys.
  """

  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Initializes options for the plug (no transformation by default).

  ## Parameters

    - opts: the plug options.

  ## Returns

    - The same options, unmodified.
  """
  @spec init(any()) :: any()
  def init(default), do: default

  @doc """
  Authenticates the request by API key.

  ## Parameters

    - conn: the connection struct.
    - _opts: plug options (ignored).

  ## Returns

    - `conn` with `:current_user` and `:permissions` assigns on success.
    - Halts with `401 Unauthorized` or `403 Forbidden` on failure.
  """
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case get_req_header(conn, "x-api-key") do
      [api_key] ->
        # Use the GenServer's fetch function to retrieve data indirectly
        case ApiKeyCache.fetch(api_key) do
          {:ok, %{user: user, permissions: permissions}} ->
            conn
            |> assign(:current_user, user)
            |> assign(:permissions, permissions)

          :error ->
            fetch_and_cache_api_key_data(conn, api_key)
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized: Missing API Key"})
        |> halt()
    end
  end

  @doc false
  @spec fetch_and_cache_api_key_data(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  defp fetch_and_cache_api_key_data(conn, api_key) do
    case Phoexnip.ServiceUtils.get_by(Phoexnip.Settings.ApiKey, %{key: api_key}) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized: Invalid API Key"})
        |> halt()

      db_key ->
        if NaiveDateTime.compare(db_key.valid_until, NaiveDateTime.utc_now()) == :gt do
          user = Phoexnip.Users.UserService.get_user_by(%{email: db_key.given_to})

          if user do
            permissions = Phoexnip.UserRolesService.fetch_highest_permission_for_users(user)
            cached_data = %{user: user, permissions: permissions}

            # Use ApiKeyCache.store/3 to indirectly write to the protected ETS table
            ApiKeyCache.store(api_key, cached_data)

            conn
            |> assign(:current_user, user)
            |> assign(:permissions, permissions)
          else
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Unauthorized: Invalid API Key"})
            |> halt()
          end
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Forbidden: API key expired"})
          |> halt()
        end
    end
  end
end
