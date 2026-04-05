defmodule PhoexnipWeb.Live.SessionExpiryHook do
  use Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    session_expiry = session["session_expiry"] || 0

    if now > session_expiry && session["user_token"] do
      {:halt, socket |> redirect(to: "/")}
    else
      timer_ref = Process.send_after(self(), :check_session, 100)

      {:cont,
       socket
       |> assign(:session_expiry, session_expiry)
       |> assign(:expiry_timer, timer_ref)}
    end
  end
end
