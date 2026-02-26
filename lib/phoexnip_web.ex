defmodule PhoexnipWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use PhoexnipWeb, :controller
      use PhoexnipWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images uploads favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: PhoexnipWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: PhoexnipWeb.Gettext

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {PhoexnipWeb.Layouts, :app}

      unquote(html_helpers())

      on_mount PhoexnipWeb.Live.SessionExpiryHook

      # Default event to handle presence_diff when a user connects to the system.
      @impl true
      def handle_info(
            %Phoenix.Socket.Broadcast{
              topic: "users:online",
              event: "presence_diff",
              payload: _diff
            },
            socket
          ) do
        presences = PhoexnipWeb.Presence.list("users:online")
        new_socket = %{socket | assigns: Map.put(socket.assigns, :presences, presences)}

        {:noreply, new_socket}
      end

      # Default implementation for the events :user_added and :user_removed that are broadcasted by: 1. Users Index.ex and 2. Settings -> Reports -> User Login Report
      @impl true
      def handle_info({event, _user_id}, socket) when event in [:user_added, :user_removed] do
        {:noreply, socket}
      end

      def handle_info(:check_session, socket) do
        now = DateTime.utc_now() |> DateTime.to_unix()
        session_expiry = socket.assigns[:session_expiry] || 0

        if now > session_expiry && socket.assigns[:current_user] do
          {:noreply, socket |> redirect(to: "/")}
        else
          # Cancel existing timer before setting a new one
          PhoexnipWeb.Live.SessionExpiryHook.cancel_existing_check_session_timer()

          # Reschedule session check
          timer_ref = Process.send_after(self(), :check_session, 60_000)
          # Store globally
          PhoexnipWeb.Live.SessionExpiryHook.store_check_session_timer(timer_ref)

          {:noreply, socket}
        end
      end
    end
  end

  def hacking_live_view do
    quote do
      use Phoenix.LiveView,
        layout: {PhoexnipWeb.Layouts, :app}

      unquote(html_helpers())

      on_mount PhoexnipWeb.Live.SessionExpiryHook

      # Debounce logic so that presence_diff does not trigger a UI update for pages that track user online status.
      @impl true
      def handle_info(
            %Phoenix.Socket.Broadcast{
              topic: "users:online",
              event: "presence_diff",
              payload: _payload
            },
            socket
          ) do
        # When a presence_diff arrives, cancel any existing timer...
        if Map.has_key?(socket.assigns, :presence_update_timer) do
          if timer = socket.assigns.presence_update_timer do
            Process.cancel_timer(timer)
          end
        end

        # ...and schedule an update after the grace period.
        timer = Process.send_after(self(), :update_presences, 3000)
        {:noreply, assign(socket, presence_update_timer: timer)}
      end

      # Checks if the current Presence.list is the same as the initial one stored at PresenceTracker.ex::on_mount and updated by the live view choosing to handle added_user, and remove_user events themselves.
      @impl true
      def handle_info(:update_presences, socket) do
        new_presences = PhoexnipWeb.Presence.list("users:online")
        old_presences = socket.assigns.old_presences || %{}

        # Compare keys: find user IDs that were present before but are missing now.
        removed_user_ids =
          old_presences
          |> Map.keys()
          |> Enum.reject(fn user_id -> Map.has_key?(new_presences, user_id) end)

        # For each removed user, broadcast a custom event.
        Enum.each(removed_user_ids, fn user_id ->
          Phoenix.PubSub.broadcast(Phoexnip.PubSub, "users:online", {:user_removed, user_id})
        end)

        # Update the socket's stored presence state.
        new_socket =
          socket
          |> assign(
            presences: new_presences,
            old_presences: new_presences,
            presence_update_timer: nil
          )

        {:noreply, new_socket}
      end

      def handle_info(:check_session, socket) do
        now = DateTime.utc_now() |> DateTime.to_unix()
        session_expiry = socket.assigns[:session_expiry] || 0

        if now > session_expiry && socket.assigns[:current_user] do
          {:noreply, socket |> redirect(to: "/")}
        else
          # Cancel existing timer before setting a new one
          PhoexnipWeb.Live.SessionExpiryHook.cancel_existing_check_session_timer()

          # Reschedule session check
          timer_ref = Process.send_after(self(), :check_session, 60_000)
          # Store globally
          PhoexnipWeb.Live.SessionExpiryHook.store_check_session_timer(timer_ref)

          {:noreply, socket}
        end
      end

      @impl true
      def handle_info({:put_flash, {content, opts}}, socket) do
        kind = Keyword.get(opts, :kind, :info)
        reset = Keyword.get(opts, :reset, nil)

        socket =
          if reset != nil do
            Phoexnip.ImportUtils.reset_upload(socket, reset)
          else
            socket
          end

        {:noreply,
         socket
         |> clear_flash()
         |> put_flash(kind, content)}
      end
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import PhoexnipWeb.CoreComponents
      use Gettext, backend: PhoexnipWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: PhoexnipWeb.Endpoint,
        router: PhoexnipWeb.Router,
        statics: PhoexnipWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
