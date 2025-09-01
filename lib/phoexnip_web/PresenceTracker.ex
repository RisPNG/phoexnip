defmodule PhoexnipWeb.PresenceTracker do
  use Phoenix.LiveView
  alias PhoexnipWeb.Presence

  @topic "users:online"
  # 10 seconds debounce

  @doc """
  On-mount hook: Subscribe to the presence topic and store the current presence list.
  """
  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Phoexnip.PubSub, @topic)

      if current_user = socket.assigns[:current_user] do
        user_id = current_user.id
        current_presences = Presence.list(@topic)

        # Only track and broadcast the event if the user isn't already in the presence list.
        if not Map.has_key?(current_presences, to_string(user_id)) do
          Presence.track(self(), @topic, user_id, %{
            online_at: System.system_time(:second)
          })

          Phoenix.PubSub.broadcast(Phoexnip.PubSub, @topic, {:user_added, user_id})
        else
          :ok
        end
      end
    end

    {:cont,
     assign(socket, presences: Presence.list(@topic), old_presences: Presence.list(@topic))}
  end
end
