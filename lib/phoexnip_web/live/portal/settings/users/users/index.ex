defmodule PhoexnipWeb.UsersLive.Index do
  use PhoexnipWeb, :hacking_live_view

  alias Phoexnip.Users.UserService

  @impl true
  def mount(_params, _session, socket) do
    socket = Phoexnip.AuthenticationUtils.check_page_permissions(socket, "SET1", 1)

    %{entries: entries, total_entries: total_entries, total_pages: total_pages} =
      Phoexnip.SearchUtils.search(
        args: %{super_user: false},
        pagination: %{
          page: 1,
          per_page: 20
        },
        module: Phoexnip.Users.User,
        preload: [:user_roles]
      )

    {:ok,
     stream(
       socket
       |> assign(:name, "")
       |> assign(:email, "")
       |> assign(:phone, "")
       |> assign(:group, "")
       |> assign(
         :error_message,
         if length(entries) > 0 do
           false
         else
           true
         end
       )
       |> assign(:form, to_form(%{}))
       |> assign(:page, 1)
       |> assign(:per_page, 20)
       |> assign(:total_entries, total_entries)
       |> assign(:total_pages, total_pages)
       |> assign(:page_title, "Users")
       |> assign(:breadcrumb_first_segment, "Settings")
       |> assign(:breadcrumb_second_segment, "Users")
       |> assign(:breadcrumb_second_link, "users")
       |> assign(
         :breadcrumb_third_segment,
         nil
       )
       |> assign(:breadcrumb_fourth_segment, nil)
       |> assign(:breadcrumb_help_link, "users/user_manual"),
       :users_collection,
       entries
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Users")
    |> assign(:users_collection, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = UserService.get!(id)

    case UserService.delete_user(user) do
      {:ok, _} ->
        # Create the audit log after customer creation
        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "User",
          # Entity ID
          user.id,
          # Action type
          "delete",
          # User who performed the action
          socket.assigns.current_user,
          user.email,
          # New data (changes)
          %{},
          # Previous data (empty since it's a new record)
          user
          # Metadata (example: user's IP)
        )

        %{entries: entries, total_entries: total_entries, total_pages: total_pages} =
          Phoexnip.SearchUtils.search(
            args: %{
              name: socket.assigns.name,
              email: socket.assigns.email,
              phone: socket.assigns.phone,
              group: socket.assigns.group,
              super_user: false
            },
            pagination: %{
              page: 1,
              per_page: socket.assigns.per_page
            },
            module: Phoexnip.Users.User,
            preload: [:user_roles]
          )

        if entries == [] do
          # Update the socket with an error message
          {:noreply,
           socket
           |> assign(:error_message, true)
           |> assign(:total_pages, 1)
           |> assign(:page, 1)
           |> assign(:total_entries, total_entries)
           |> assign(:users_collection, [])}
        else
          # Update the socket with the search results and clear any error message
          {:noreply,
           socket
           |> assign(:error_message, nil)
           |> assign(:page, 1)
           |> assign(:per_page, socket.assigns.per_page)
           |> assign(:total_entries, total_entries)
           |> assign(:total_pages, total_pages)
           |> put_flash(:info, "User " <> user.name <> " has been deleted!")
           |> stream(:users_collection, entries)}
        end

      {:error, error} ->
        IO.inspect(error)
        {:noreply, socket}
    end
  end

  def handle_event(
        "search",
        %{
          "name" => name,
          "email" => email,
          "phone" => phone,
          "group" => group
        },
        socket
      ) do
    socket =
      socket
      |> assign(:name, name)
      |> assign(:email, email)
      |> assign(:phone, phone)
      |> assign(:group, group)

    %{entries: entries, total_entries: total_entries, total_pages: total_pages} =
      Phoexnip.SearchUtils.search(
        args: %{
          name: socket.assigns.name,
          email: socket.assigns.email,
          phone: socket.assigns.phone,
          group: socket.assigns.group,
          super_user: false
        },
        pagination: %{
          page: 1,
          per_page: socket.assigns.per_page
        },
        module: Phoexnip.Users.User,
        preload: [:user_roles]
      )

    # Check if the result is empty
    if entries == [] do
      # Update the socket with an error message
      {:noreply,
       socket
       |> assign(:error_message, true)
       |> assign(:total_pages, 1)
       |> assign(:page, 1)
       |> assign(:total_entries, total_entries)
       |> assign(:users_collection, [])}
    else
      # Update the socket with the search results and clear any error message
      {:noreply,
       socket
       |> assign(:error_message, nil)
       |> assign(:page, 1)
       |> assign(:per_page, socket.assigns.per_page)
       |> assign(:total_entries, total_entries)
       |> assign(:total_pages, total_pages)
       |> stream(:users_collection, entries)}
    end
  end

  # clear form
  def handle_event("reset_form", _params, socket) do
    socket =
      socket
      |> assign(:name, "")
      |> assign(:email, "")
      |> assign(:phone, "")
      |> assign(:group, "")

    %{entries: entries, total_entries: total_entries, total_pages: total_pages} =
      Phoexnip.SearchUtils.search(
        args: %{
          name: socket.assigns.name,
          email: socket.assigns.email,
          phone: socket.assigns.phone,
          group: socket.assigns.group,
          super_user: false
        },
        pagination: %{
          page: 1,
          per_page: socket.assigns.per_page
        },
        module: Phoexnip.Users.User,
        preload: [:user_roles]
      )

    # Check if the result is empty
    if entries == [] do
      # Update the socket with an error message
      {:noreply,
       socket
       |> assign(:error_message, true)
       |> assign(:total_pages, 1)
       |> assign(:page, 1)
       |> assign(:total_entries, total_entries)
       |> assign(:users_collection, [])}
    else
      # Update the socket with the search results and clear any error message
      {:noreply,
       socket
       |> assign(:error_message, nil)
       |> assign(:page, 1)
       |> assign(:per_page, socket.assigns.per_page)
       |> assign(:total_entries, total_entries)
       |> assign(:total_pages, total_pages)
       |> stream(:users_collection, entries)}
    end
  end

  # for pagination
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    # Reuse the search mechanism to get the filtered list.
    %{entries: entries, total_entries: total_entries, total_pages: total_pages} =
      Phoexnip.SearchUtils.search(
        args: %{
          name: socket.assigns.name,
          email: socket.assigns.email,
          phone: socket.assigns.phone,
          group: socket.assigns.group,
          super_user: false
        },
        pagination: %{
          page: page,
          per_page: socket.assigns.per_page
        },
        module: Phoexnip.Users.User,
        preload: [:user_roles]
      )

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:total_entries, total_entries)
     |> stream(:users_collection, entries)}
  end

  @impl true
  def handle_event("live_select_change", %{"id" => id} = params, socket) do
    text = Map.get(params, "text", "")

    options =
      cond do
        String.starts_with?(id, "live-single-select-user-name") ->
          Phoexnip.SearchUtils.search(
            args: %{name: text, super_user: false},
            pagination: %{
              page: 1,
              per_page: 20
            },
            module: Phoexnip.Users.User,
            preload: [:user_roles]
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.name}", &1.name})
          |> (fn opts ->
                if text != "" and
                     not Enum.any?(opts, fn {opt, _} -> String.downcase(opt) == text end) do
                  [{text, text} | opts]
                else
                  opts
                end
              end).()

        String.starts_with?(id, "live-single-select-user-email") ->
          Phoexnip.SearchUtils.search(
            args: %{email: text, super_user: false},
            pagination: %{
              page: 1,
              per_page: 20
            },
            module: Phoexnip.Users.User,
            preload: [:user_roles]
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.email}", &1.email})
          |> (fn opts ->
                if text != "" and
                     not Enum.any?(opts, fn {opt, _} -> String.downcase(opt) == text end) do
                  [{text, text} | opts]
                else
                  opts
                end
              end).()

        String.starts_with?(id, "live-single-select-user-phone") ->
          Phoexnip.SearchUtils.search(
            args: %{phone: text, super_user: false},
            pagination: %{
              page: 1,
              per_page: 20
            },
            module: Phoexnip.Users.User,
            preload: [:user_roles]
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.phone}", &1.phone})
          # Filter out duplicates
          |> Enum.uniq_by(fn {phone, _} -> phone end)
          # Filter out empty strings
          |> Enum.reject(fn {phone, _} -> phone == "" end)
          |> (fn opts ->
                if text != "" and
                     not Enum.any?(opts, fn {opt, _} -> String.downcase(opt) == text end) do
                  [{text, text} | opts]
                else
                  opts
                end
              end).()

        String.starts_with?(id, "live-single-select-user-group") ->
          Phoexnip.SearchUtils.search(
            args: %{group: text, super_user: false},
            pagination: %{
              page: 1,
              per_page: 20
            },
            module: Phoexnip.Users.User,
            preload: [:user_roles]
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.group}", &1.group})
          # Filter out duplicates
          |> Enum.uniq_by(fn {group, _} -> group end)
          # Filter out empty strings
          |> Enum.reject(fn {group, _} -> group == "" end)
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
  def handle_info({event, _user_id} = _msg, socket) when event in [:user_added, :user_removed] do
    presences = PhoexnipWeb.Presence.list("users:online")

    # Reuse the search mechanism to get the filtered list.
    %{entries: entries, total_entries: total_entries, total_pages: total_pages} =
      Phoexnip.SearchUtils.search(
        args: %{
          name: socket.assigns.name,
          email: socket.assigns.email,
          phone: socket.assigns.phone,
          group: socket.assigns.group,
          super_user: false
        },
        pagination: %{
          page: socket.assigns.page,
          per_page: socket.assigns.per_page
        },
        module: Phoexnip.Users.User,
        preload: [:user_roles]
      )

    new_socket =
      socket
      |> assign(:presences, presences)
      |> assign(:presence_last_updated, :os.system_time(:millisecond))
      |> assign(:page, socket.assigns.page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_entries, total_entries)
      |> stream(:users_collection, entries)

    {:noreply, new_socket}
  end
end
