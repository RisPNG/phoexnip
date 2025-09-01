defmodule PhoexnipWeb.RolesLive.Index do
  use PhoexnipWeb, :live_view

  alias Phoexnip.RolesService

  @impl true
  def mount(_params, _session, socket) do
    socket = Phoexnip.AuthenticationUtils.check_page_permissions(socket, "SET2", 1)

    per_page = 10
    page = 1

    %{entries: entries, total_pages: total_pages, total_entries: total_entries} =
      Phoexnip.SearchUtils.search(
        pagination: %{page: page, per_page: per_page},
        module: Phoexnip.Roles
      )

    {:ok,
     stream(
       socket
       |> assign(:name, "")
       |> assign(:description, "")
       |> assign(:error_message, false)
       |> assign(:page, page)
       |> assign(:per_page, per_page)
       |> assign(:form, to_form(%{}))
       |> assign(:total_entries, total_entries)
       |> assign(:total_pages, total_pages)
       |> assign(:breadcrumb_first_segment, "Settings")
       |> assign(:breadcrumb_second_segment, "Roles")
       |> assign(:breadcrumb_second_link, "roles")
       |> assign(
         :breadcrumb_third_segment,
         nil
       )
       |> assign(:breadcrumb_fourth_segment, nil)
       |> assign(:show_audit_log_modal, false)
       |> assign(:breadcrumb_help_link, "roles/user_manual"),
       :roles_collection,
       entries
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Roles")
    |> assign(:roles_collection, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    roles = RolesService.get!(id)

    case RolesService.delete(roles) do
      {:ok, _} ->
        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "Roles",
          # Entity ID
          roles.id,
          # Action type
          "delete",
          # User who performed the action
          socket.assigns.current_user,
          # New data (changes)
          roles.name,
          %{},
          # Previous data (empty since it's a new record)
          roles
          # Metadata (example: user's IP)
        )

        %{entries: entries, total_pages: total_pages, total_entries: total_entries} =
          Phoexnip.SearchUtils.search(
            args: %{name: socket.assigns.name, description: socket.assigns.description},
            pagination: %{
              page: 1,
              per_page: socket.assigns.per_page
            },
            module: Phoexnip.Roles
          )

        # Check if the result is empty
        if entries == [] do
          # Update the socket with an error message
          {:noreply,
           socket
           |> assign(:error_message, true)
           |> assign(:page, 1)
           |> assign(:total_pages, total_pages)
           |> assign(:total_entries, total_entries)
           |> assign(:roles_collection, [])}
        else
          # Update the socket with the search results and clear any error message
          {:noreply,
           socket
           |> assign(:error_message, nil)
           |> assign(:page, 1)
           |> assign(:per_page, socket.assigns.per_page)
           |> assign(:total_entries, total_entries)
           |> assign(:total_pages, total_pages)
           |> put_flash(:info, "Roles " <> roles.name <> " has been deleted!")
           |> stream(:roles_collection, entries)}
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
          "description" => description
        },
        socket
      ) do
    socket =
      socket
      |> assign(:name, name)
      |> assign(:description, description)

    %{entries: entries, total_pages: total_pages, total_entries: total_entries} =
      Phoexnip.SearchUtils.search(
        args: %{name: socket.assigns.name, description: socket.assigns.description},
        pagination: %{
          page: 1,
          per_page: socket.assigns.per_page
        },
        module: Phoexnip.Roles
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
       |> assign(:roles_collection, [])}
    else
      # Update the socket with the search results and clear any error message
      {:noreply,
       socket
       |> assign(:error_message, nil)
       |> assign(:page, 1)
       |> assign(:total_pages, total_pages)
       |> assign(:per_page, socket.assigns.per_page)
       |> assign(:total_entries, total_entries)
       |> stream(:roles_collection, entries)}
    end
  end

  # clear form
  def handle_event("reset_form", _params, socket) do
    socket =
      socket
      |> assign(:name, "")
      |> assign(:description, "")

    %{entries: entries, total_pages: total_pages, total_entries: total_entries} =
      Phoexnip.SearchUtils.search(
        args: %{name: socket.assigns.name, description: socket.assigns.description},
        pagination: %{
          page: 1,
          per_page: socket.assigns.per_page
        },
        module: Phoexnip.Roles
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
       |> assign(:roles_collection, [])}
    else
      # Update the socket with the search results and clear any error message
      {:noreply,
       socket
       |> assign(:error_message, nil)
       |> assign(:page, 1)
       |> assign(:per_page, socket.assigns.per_page)
       |> assign(:total_entries, total_entries)
       |> assign(:total_pages, total_pages)
       |> stream(:roles_collection, entries)}
    end
  end

  # for pagination
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)

    %{entries: entries, total_pages: total_pages} =
      Phoexnip.SearchUtils.search(
        args: %{name: socket.assigns.name, description: socket.assigns.description},
        pagination: %{
          page: page,
          per_page: socket.assigns.per_page
        },
        module: Phoexnip.Roles
      )

    # Check if the result is empty
    if entries == [] do
      # Update the socket with an error message
      {:noreply,
       socket
       |> assign(:error_message, true)
       |> assign(:total_pages, 1)
       |> assign(:page, 1)
       |> assign(:roles_collection, [])}
    else
      # Update the socket with the search results and clear any error message
      {:noreply,
       socket
       |> assign(:error_message, nil)
       |> assign(:page, 1)
       |> assign(:total_pages, total_pages)
       |> stream(:roles_collection, entries)}
    end
  end

  @impl true
  def handle_event("live_select_change", %{"id" => id} = params, socket) do
    text = Map.get(params, "text", "")

    options =
      cond do
        String.starts_with?(id, "live-single-select-name") ->
          Phoexnip.SearchUtils.search(
            ags: %{name: text},
            pagination: %{
              page: 1,
              per_page: socket.assigns.per_page
            },
            module: Phoexnip.Roles
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.name}", &1.name})
          # Filter out duplicates
          |> Enum.uniq_by(fn {name, _} -> name end)
          # Filter out empty strings
          |> Enum.reject(fn {name, _} -> name == "" end)
          |> (fn opts ->
                if text != "" and
                     not Enum.any?(opts, fn {opt, _} -> String.downcase(opt) == text end) do
                  [{text, text} | opts]
                else
                  opts
                end
              end).()

        String.starts_with?(id, "live-single-select-description") ->
          Phoexnip.SearchUtils.search(
            args: %{description: text},
            pagination: %{
              page: 1,
              per_page: socket.assigns.per_page
            },
            module: Phoexnip.Roles
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.description}", &1.description})
          # Filter out duplicates
          |> Enum.uniq_by(fn {description, _} -> description end)
          # Filter out empty strings
          |> Enum.reject(fn {description, _} -> description == "" end)
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

  def handle_event(
        "open_audit_log_modal",
        %{"id" => id, "name" => name, "inserted_at" => inserted_at},
        socket
      ) do
    audit_log_data = %{
      id: id,
      name: name,
      inserted_at:
        case DateTime.from_iso8601(inserted_at) do
          {:ok, datetime, _offset} ->
            datetime

          {:error, _reason} ->
            # Handle error case or set a default value if needed
            nil
        end
    }

    socket =
      socket
      |> assign(:audit_log_data, audit_log_data)
      |> assign(:show_audit_log_modal, true)

    {:noreply, socket}
  end

  def handle_event("close_audit_log_modal", _params, socket) do
    {:noreply, assign(socket, show_audit_log_modal: false)}
  end
end
