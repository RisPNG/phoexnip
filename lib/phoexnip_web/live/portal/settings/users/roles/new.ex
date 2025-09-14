defmodule PhoexnipWeb.RolesLive.New do
  use PhoexnipWeb, :live_view

  alias Phoexnip.SitemapService
  alias Phoexnip.Roles
  alias Phoexnip.ServiceUtils
  alias Phoexnip.UserRolesService
  import Ecto.Query, warn: false

  @impl true
  def mount(params, _session, socket) do
    if params == %{} do
      socket = Phoexnip.AuthenticationUtils.check_page_permissions(socket, "SET2", 2)

      # Fetch the sitemap data
      sitemap_entries = SitemapService.list() |> Enum.sort_by(& &1.sequence)

      # Transform sitemap data into RolesPermission structs
      role_permissions =
        Enum.map(sitemap_entries, fn entry ->
          %{
            # Set your default permission here
            permission: 0,
            sitemap_code: entry.code,
            sitemap_name: entry.displayname,
            sitemap_level: entry.level,
            sitemap_parent: entry.parent,
            sitemap_url: entry.url,
            sequence: entry.sequence
          }
        end)

      # Create a new role with associated role_permissions
      changeset =
        %Roles{}
        |> Roles.changeset(%{role_permissions: role_permissions})

      highest_permissions =
        UserRolesService.fetch_highest_permission_for_users(socket.assigns.current_user)
        |> Enum.filter(fn rp -> rp.permission == 16 end)

      {:ok,
       socket
       |> assign(:page_title, "New Roles")
       |> assign(:form, changeset)
       |> assign(:role, %Roles{})
       |> assign(:highest_permission, highest_permissions)
       |> assign(:breadcrumb_first_segment, "Settings")
       |> assign(:breadcrumb_second_segment, "Roles")
       |> assign(:breadcrumb_second_link, "roles")
       |> assign(
         :breadcrumb_third_segment,
         "New"
       )
       |> assign(:breadcrumb_fourth_segment, nil)
       |> assign(:breadcrumb_help_link, "roles/user_manual")}
    else
      socket = Phoexnip.AuthenticationUtils.check_page_permissions(socket, "SET2", 4)

      highest_permissions =
        UserRolesService.fetch_highest_permission_for_users(socket.assigns.current_user)
        |> Enum.filter(fn rp -> rp.permission == 16 end)

      role =
        ServiceUtils.get_with_preload!(
          Phoexnip.Roles,
          String.to_integer(params["id"]),
          [role_permissions: from(rp in Phoexnip.RolesPermission, order_by: rp.id)]
        )

      sitemap_entries = SitemapService.list() |> Enum.sort_by(& &1.sequence)

      # 1. Build a map from sitemap_code → the existing permission struct
      existing_by_code =
        role.role_permissions
        |> Enum.map(fn perm ->
          {perm.sitemap_code, perm}
        end)
        |> Enum.into(%{})

      # 2. Now walk over all sitemap_entries and either “take over” the existing entry (with its id)
      #    or build a new map if it’s missing.
      role_permissions =
        sitemap_entries
        |> Enum.map(fn entry ->
          case Map.get(existing_by_code, entry.code) do
            # If there is already a matching permission, pull in its fields (including id)
            %_{id: existing_id} = existing ->
              IO.inspect(existing, label: "existing")

              %{
                id: existing_id,
                permission: existing.permission,
                sitemap_code: existing.sitemap_code,
                sitemap_name: existing.sitemap_name,
                sitemap_level: existing.sitemap_level,
                sitemap_parent: existing.sitemap_parent,
                sitemap_url: existing.sitemap_url,
                sequence: existing.sequence
              }

            # Otherwise, build a fresh map with permission = 0 (no id)
            nil ->
              %{
                # new permission default:
                permission: 0,
                sitemap_code: entry.code,
                sitemap_name: entry.displayname,
                sitemap_level: entry.level,
                sitemap_parent: entry.parent,
                sitemap_url: entry.url,
                sequence: entry.sequence
              }
          end
        end)

      changeset = ServiceUtils.change(role, %{role_permissions: role_permissions})

      {:ok,
       socket
       |> assign(:page_title, "Edit Roles")
       |> assign(:role, role)
       |> assign(:highest_permission, highest_permissions)
       |> assign(:form, changeset)
       |> assign(:breadcrumb_first_segment, "Settings")
       |> assign(:breadcrumb_second_segment, "Roles")
       |> assign(:breadcrumb_second_link, "roles")
       |> assign(
         :breadcrumb_third_segment,
         "Edit"
       )
       |> assign(:breadcrumb_fourth_segment, "" <> role.name)
       |> assign(:breadcrumb_help_link, "roles/user_manual")}
    end
  end

  @impl true
  def handle_event("save", %{"role" => params}, socket) do
    old_role = socket.assigns.role

    if old_role.id == nil do
      case ServiceUtils.create(Phoexnip.Roles, params) do
        {:ok, role} ->
          Phoexnip.AuditLogService.create_audit_log(
            # Entity type
            "Roles",
            # Entity ID
            role.id,
            # Action type
            "create",
            # User who performed the action
            socket.assigns.current_user,
            role.name,
            # New data (changes)
            role,
            # Previous data (empty since it's a new record)
            %{}
            # Metadata (example: user's IP)
          )

          {:noreply,
           socket
           |> put_flash(:info, "Roles " <> role.name <> " is successfully created.")
           |> push_navigate(to: ~p"/roles/")}

        {:error, errors} ->
          {:noreply, assign(socket, :form, errors)}
      end
    else
      case ServiceUtils.update(old_role, params) do
        {:ok, role} ->
          Phoexnip.AuditLogService.create_audit_log(
            # Entity type
            "Roles",
            # Entity ID
            role.id,
            # Action type
            "update",
            # User who performed the action
            socket.assigns.current_user,
            # New data (changes)
            role.name,
            role,
            # Previous data (empty since it's a new record)
            old_role
            # Metadata (example: user's IP)
          )

          {:noreply,
           socket
           |> put_flash(:info, "Roles " <> role.name <> " is successfully updated.")
           |> push_navigate(to: ~p"/roles/")}

        {:error, errors} ->
          {:noreply, assign(socket, :form, errors)}
      end
    end
  end

  def handle_event("validate", %{"role" => params}, socket) do
    changeset =
      %Roles{}
      |> ServiceUtils.change(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: changeset)}
  end
end
