defmodule PhoexnipWeb.Live.SessionExpiryHook do
  use Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    session_expiry = session["session_expiry"] || 0

    # Cancel any existing timer globally before setting a new one
    cancel_existing_check_session_timer()

    if now > session_expiry && session["user_id"] do
      {:halt, socket |> redirect(to: "/")}
    else
      # Schedule a new session check
      timer_ref = Process.send_after(self(), :check_session, 100)
      # Store globally
      store_check_session_timer(timer_ref)

      {:cont, assign(socket, :session_expiry, session_expiry)}
    end
  end

  # Store the latest timer reference globally
  def store_check_session_timer(timer_ref) do
    :persistent_term.put(:check_session_timer, timer_ref)
  end

  # Cancel the existing timer if it exists
  def cancel_existing_check_session_timer() do
    case :persistent_term.get(:check_session_timer, nil) do
      # No existing timer
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end
  end
end
