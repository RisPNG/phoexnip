defmodule PhoexnipWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoexnip

  @secure_cookies Application.compile_env(:phoexnip, :secure_cookies, false)
  # The session will be stored in the cookie and signed,
  # encrypted, and protected with HttpOnly and SameSite attributes.
  @session_options [
    store: :cookie,
    key: "_phoexnip_key",
    signing_salt: "Ld429k3N",
    encryption_salt: "9Kc3zN8m",
    http_only: true,
    secure: @secure_cookies,
    same_site: "Lax",
    max_age: 43_190
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :phoexnip,
    gzip: false,
    only: PhoexnipWeb.static_paths()

  plug Plug.Static,
    at: "/uploads",
    from: "priv/static/uploads",
    gzip: false

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :phoexnip

    plug Phoenix.LiveDashboard.RequestLogger,
      param_key: "request_logger",
      cookie_key: "request_logger"
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    length: 100 * 1024 * 1024

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug PhoexnipWeb.Router
end
