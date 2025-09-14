defmodule PhoexnipWeb.UsersLoginReport.Index do
  use PhoexnipWeb, :hacking_live_view

  @moduledoc """
  LiveView for the User Login Report page.

  Provides a paginated view of user login audit entries with filtering by user
  and date range, plus a real-time summary of currently online users.
  Enforces level-two permissions for access.
  """

  alias Phoexnip.Repo

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    purchase_reports =
      Phoexnip.UserRolesService.fetch_level_two_user_permissions(user, "SET6")

    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        purchase_reports,
        "SET6A",
        1
      )

    per_page = 10
    page = 1
    total_entries = Repo.aggregate(Phoexnip.Users.User, :count, :id)

    {:ok,
     socket
     |> assign(purchase_reports: purchase_reports)
     |> assign(current_section: "User Login Report")
     |> assign(show_results: "hidden")
     |> assign(:user, nil)
     |> assign(:from_date, nil)
     |> assign(:to_date, nil)
     |> assign(:page, page)
     |> assign(:total_online, 0)
     |> assign(:per_page, per_page)
     |> assign(:total_entries, total_entries)
     |> assign(:breadcrumb_first_segment, "Settings")
     |> assign(:breadcrumb_second_segment, "Reports")
     |> assign(:breadcrumb_second_link, nil)
     |> assign(:breadcrumb_third_segment, "User Login Report")
     |> assign(:breadcrumb_third_link, "settings_reports/user_login_report")
     |> assign(:breadcrumb_help_link, nil)
     |> assign(:error_message, false)
     |> assign(:total_pages, Float.ceil(total_entries / per_page) |> round())
     |> assign(:form, to_form(%{}))
     |> stream(:request_collection, %{})
     |> stream(:currently_online, %{})}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "User Login Report")
    |> assign(:request_collection, nil)
  end

  def handle_event(
        "search",
        %{
          "user" => user,
          "from_date" => from_date,
          "to_date" => to_date
        },
        socket
      ) do
    user_id_filter =
      if user in ["", nil] do
        %{user_id: [1, "after"]}
      else
        %{user_id: String.to_integer(user)}
      end

    %{entries: entries, total_pages: total_pages, total_entries: total_entries} =
      Phoexnip.SearchUtils.search(
        args:
          %{
            # Default login success
            entity_id: -2
          }
          |> Map.merge(user_id_filter)
          |> Map.merge(
            Phoexnip.SearchUtils.construct_date_map(
              from_date,
              if to_date in ["", nil] do
                to_date
              else
                to_date <> " 23:59"
              end,
              :inserted_at
            )
          ),
        pagination: %{page: 1, per_page: 10},
        module: Phoexnip.AuditLogs,
        order_by: :inserted_at,
        order_method: :desc
      )

    current_online_users = PhoexnipWeb.Presence.list("users:online")

    user_ids_online =
      current_online_users
      |> Map.keys()
      |> Enum.map(&String.to_integer/1)
      |> Enum.reject(&(&1 == 1))

    online_users =
      if length(user_ids_online) > 0 do
        %{entries: entries} =
          Phoexnip.SearchUtils.search(
            args: %{
              id: user_ids_online ++ ["or"],
              super_user: false
            },
            module: Phoexnip.Users.User,
            order_by: :name
          )

        Enum.group_by(entries, & &1.group)
        |> Enum.map(fn {group, users} ->
          %{
            # Use group as a unique identifier
            id: group,
            group: group,
            # Keep users nested inside
            users: users
          }
        end)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:error_message, length(entries) == 0)
     |> assign(show_results: "")
     |> assign(:user, user_id_filter)
     |> assign(:from_date, from_date)
     |> assign(:to_date, to_date)
     |> assign(:total_pages, total_pages)
     |> assign(:total_entries, total_entries)
     |> assign(:total_online, length(online_users))
     |> stream(:request_collection, entries)
     |> stream(:currently_online, online_users)}
  end

  def handle_event("validate", params, socket) do
    {:noreply,
     socket
     |> assign(form: to_form(params))}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)

    user_id_filter =
      if socket.assigns.user in ["", nil] do
        %{user_id: [1, "after"]}
      else
        socket.assigns.user
      end

    %{entries: entries, total_pages: total_pages, total_entries: total_entries} =
      Phoexnip.SearchUtils.search(
        args:
          %{
            # Default login success
            entity_id: -2
          }
          |> Map.merge(user_id_filter)
          |> Map.merge(
            Phoexnip.SearchUtils.construct_date_map(
              socket.assigns.from_date,
              if(socket.assigns.to_date in ["", nil]) do
                socket.assigns.to_date
              else
                socket.assigns.to_date <> " 23:59"
              end,
              :inserted_at
            )
          ),
        pagination: %{page: page, per_page: 10},
        module: Phoexnip.AuditLogs,
        order_by: :inserted_at,
        order_method: :desc
      )

    presences = PhoexnipWeb.Presence.list("users:online")

    user_ids_online =
      presences
      |> Map.keys()
      |> Enum.map(&String.to_integer/1)
      |> Enum.reject(&(&1 == 1))

    online_users =
      if length(user_ids_online) > 0 do
        %{entries: entries} =
          Phoexnip.SearchUtils.search(
            args: %{
              id: user_ids_online ++ ["or"],
              super_user: false
            },
            module: Phoexnip.Users.User,
            order_by: :name
          )

        Enum.group_by(entries, & &1.group)
        |> Enum.map(fn {group, users} ->
          %{
            # Use group as a unique identifier
            id: group,
            group: group,
            # Keep users nested inside
            users: users
          }
        end)
      else
        []
      end

    new_socket =
      socket
      |> assign(:presences, presences)
      |> assign(:old_presences, presences)
      |> assign(:presence_last_updated, :os.system_time(:millisecond))
      |> assign(:error_message, length(entries) == 0)
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_entries, total_entries)
      |> assign(:total_online, length(online_users))
      |> stream(:request_collection, entries)
      |> stream(:currently_online, online_users)

    {:noreply, new_socket}
  end

  # clear form
  def handle_event("reset_form", _params, socket) do
    socket =
      socket
      |> assign(:user, nil)
      |> assign(:from_date, nil)
      |> assign(:to_date, nil)
      |> assign(show_results: "hidden")

    {:noreply,
     socket
     |> assign(form: to_form(%{}))}
  end

  @impl true
  def handle_event("live_select_change", params, socket) do
    text = Map.get(params, "text", "")
    id = Map.get(params, "id", "")

    options =
      cond do
        String.starts_with?(id, "live-single-select-user") ->
          Phoexnip.SearchUtils.search(
            args: %{name: text, super_user: false},
            pagination: %{
              page: 1,
              per_page: 20
            },
            module: Phoexnip.Users.User,
            use_or: true
          )[:entries]
          |> Enum.map(&{"#{&1.name}", "#{&1.id}"})
          |> (fn opts ->
                if text != "" and
                     not Enum.any?(opts, fn {opt, _} -> String.downcase(opt) == text end) do
                  [{text, text} | opts]
                else
                  opts
                end
              end).()

        true ->
          []
      end

    send_update(LiveSelect.Component, id: id, options: options)

    {:noreply, socket}
  end

  @impl true
  def handle_info({event, user_id} = _msg, socket) when event in [:user_added, :user_removed] do
    presences = PhoexnipWeb.Presence.list("users:online")
    IO.inspect(presences, label: "presences")
    IO.puts("Received #{event} for user: #{user_id}")

    user_id_filter =
      if socket.assigns.user in ["", nil] do
        %{user_id: [1, "after"]}
      else
        socket.assigns.user
      end

    # Reuse the search mechanism to get the filtered list.
    %{entries: entries, total_pages: total_pages, total_entries: total_entries} =
      Phoexnip.SearchUtils.search(
        args:
          %{
            # Default login success
            entity_id: -2
          }
          |> Map.merge(user_id_filter)
          |> Map.merge(
            Phoexnip.SearchUtils.construct_date_map(
              socket.assigns.from_date,
              if(socket.assigns.to_date in ["", nil]) do
                socket.assigns.to_date
              else
                socket.assigns.to_date <> " 23:59"
              end,
              :inserted_at
            )
          ),
        pagination: %{page: socket.assigns.page, per_page: 10},
        module: Phoexnip.AuditLogs,
        order_by: :inserted_at,
        order_method: :desc
      )

    user_ids_online =
      presences
      |> Map.keys()
      |> Enum.map(&String.to_integer/1)
      |> Enum.reject(&(&1 == 1))

    online_users =
      if length(user_ids_online) > 0 do
        %{entries: entries} =
          Phoexnip.SearchUtils.search(
            args: %{
              id: user_ids_online ++ ["or"],
              super_user: false
            },
            module: Phoexnip.Users.User,
            order_by: :name
          )

        Enum.group_by(entries, & &1.group)
        |> Enum.map(fn {group, users} ->
          %{
            # Use group as a unique identifier
            id: group,
            group: group,
            # Keep users nested inside
            users: users
          }
        end)
      else
        []
      end

    new_socket =
      socket
      |> assign(:presences, presences)
      |> assign(:old_presences, presences)
      |> assign(:presence_last_updated, :os.system_time(:millisecond))
      |> assign(:error_message, length(entries) == 0)
      |> assign(:page, socket.assigns.page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_entries, total_entries)
      |> assign(:total_online, length(online_users))
      |> stream(:request_collection, entries)
      |> stream(:currently_online, online_users)

    {:noreply, new_socket}
  end
end
