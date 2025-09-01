defmodule PhoexnipWeb.Presence do
  use Phoenix.Presence,
    otp_app: :phoexnip,
    pubsub_server: Phoexnip.PubSub

  def user_active?(presences, user_id) do
    user_key = to_string(user_id)

    case Map.get(presences, user_key) do
      nil ->
        false

      %{metas: metas} ->
        now = :os.system_time(:second)
        # Check if any meta shows activity within the last 30 minutes (1800 seconds)
        Enum.any?(metas, fn %{online_at: online_at} ->
          now - online_at <= 30 * 60
        end)
    end
  end
end
