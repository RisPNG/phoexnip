defmodule PhoexnipWeb.MasterDataGroupsLive.Index do
  use PhoexnipWeb, :live_view

  alias Phoexnip.Masterdata.Groups
  alias Phoexnip.ServiceUtils
  alias Phoexnip.UserRolesService

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    highest_permission_masterdata =
      UserRolesService.fetch_level_two_user_permissions(user, "SET3")

    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        highest_permission_masterdata,
        "SET3N",
        1
      )

    {:ok,
     socket
     |> assign(:masterdata_permissions, highest_permission_masterdata)
     |> assign(:current_section, "Groups")
     |> assign(:breadcrumb_first_segment, "Settings")
     |> assign(:breadcrumb_second_segment, "Master Data")
     |> assign(:breadcrumb_second_link, nil)
     |> assign(
       :breadcrumb_third_segment,
       "Groups"
     )
     |> assign(:breadcrumb_third_link, "masterdata/groups")
     |> assign(:breadcrumb_fourth_segment, nil)
     |> assign(:show_audit_log_modal, false)
     |> assign(:breadcrumb_help_link, "masterdata/groups/usermanual")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        socket.assigns.masterdata_permissions,
        "SET3N",
        4
      )

    socket
    |> assign(:page_title, "Edit Groups")
    |> assign(:groups, ServiceUtils.get!(Groups, id))
    |> stream(:groups_collection, ServiceUtils.list_ordered(Groups, [asc: :sort]))
  end

  defp apply_action(socket, :new, _params) do
    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        socket.assigns.masterdata_permissions,
        "SET3N",
        2
      )

    all_groups = ServiceUtils.list_ordered(Groups, [asc: :sort])

    socket
    |> assign(:page_title, "New Groups")
    |> assign(:groups, %Groups{
      sort:
        if length(all_groups) == 0 do
          10
        else
          Enum.max_by(all_groups, & &1.sort).sort + 10
        end
    })
    |> stream(:groups_collection, all_groups)
  end

  defp apply_action(socket, :index, _params) do
    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        socket.assigns.masterdata_permissions,
        "SET3N",
        1
      )

    socket
    |> assign(:page_title, "Groups")
    |> assign(:groups, nil)
    |> stream(:groups_collection, ServiceUtils.list_ordered(Groups, [asc: :sort]))
  end

  @impl true
  def handle_info(
        {PhoexnipWeb.MasterDataGroupsLive.FormComponent, {:saved, _groups}},
        socket
      ) do
    {:noreply, stream(socket, :groups_collection, ServiceUtils.list_ordered(Groups, [asc: :sort]))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    groups = ServiceUtils.get!(Groups, id)
    {:ok, _} = ServiceUtils.delete(groups)

    Phoexnip.AuditLogService.create_audit_log(
      # Entity type
      "Groups",
      # Entity ID
      groups.id,
      # Action type
      "delete",
      # User who performed the action
      socket.assigns.current_user,
      groups.code,
      # New data (changes)
      %{},
      # Previous data (empty since it's a new record)
      groups
      # Metadata (example: user's IP)
    )

    {:noreply, stream(socket, :groups_collection, ServiceUtils.list_ordered(Groups, [asc: :sort]))}
  end

  def handle_event(
        "open_audit_log_modal",
        %{"id" => id, "code" => code, "inserted_at" => inserted_at},
        socket
      ) do
    audit_log_data = %{
      id: id,
      code: code,
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
      |> stream(:groups_collection, ServiceUtils.list_ordered(Groups, [asc: :sort]))

    {:noreply, socket}
  end

  def handle_event("close_audit_log_modal", _params, socket) do
    {:noreply,
     assign(socket, show_audit_log_modal: false)
     |> stream(:groups_collection, ServiceUtils.list_ordered(Groups, [asc: :sort]))}
  end
end
