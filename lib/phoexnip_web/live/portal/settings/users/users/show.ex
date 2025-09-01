defmodule PhoexnipWeb.UsersLive.Show do
  use PhoexnipWeb, :live_view
  @moduledoc """
  LiveView for viewing, updating, and deleting a single user.

  Loads current roles, supports avatar upload, and exposes actions for
  deletion with audit logging.
  """

  alias Phoexnip.Users.UserService

  @impl true
  def mount(_params, _session, socket) do
    socket = Phoexnip.AuthenticationUtils.check_page_permissions(socket, "SET1", 1)

    {:ok,
     socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    user = UserService.get!(id)

    roles = Phoexnip.RolesService.list(preload: false)
    existing_user_roles = user.user_roles

    # Create a map of existing roles for quick lookup
    existing_roles_map =
      Enum.reduce(existing_user_roles, %{}, fn ur, acc ->
        Map.put(acc, ur.role_id, ur)
      end)

    # Create user roles list, including new roles not yet assigned
    user_roles =
      Enum.map(roles, fn role ->
        case Map.get(existing_roles_map, role.id) do
          nil ->
            %{
              role_id: role.id,
              role_name: role.name,
              belongs_in_role: false,
              user_id: user.id
            }

          existing_role ->
            %{
              role_id: role.id,
              role_name: role.name,
              belongs_in_role: existing_role.belongs_in_role,
              user_id: user.id
            }
        end
      end)

    changeset = UserService.change_update(user, %{user_roles: user_roles})

    {:noreply,
     socket
     |> assign(:page_title, "Update User")
     |> assign(:image_url, Phoexnip.ImageUtils.image_for(user))
     |> assign(:user, user)
     |> assign(:user_id, user.id)
     |> assign(:form, changeset)
     |> assign(:uploaded_files, [])
     |> assign(:breadcrumb_first_segment, "Settings")
     |> assign(:breadcrumb_second_segment, "Users")
     |> assign(:breadcrumb_second_link, "users")
     |> assign(
       :breadcrumb_third_segment,
       "Show"
     )
     |> assign(:breadcrumb_fourth_segment, "" <> user.name <> " - " <> user.email)
     |> assign(:breadcrumb_help_link, "users/user_manual")
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .gif),
       max_entries: 1,
       auto_upload: true
     )
     |> assign(:show_audit_log_modal, false)}
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

      {:error, error} ->
        IO.inspect(error)
    end

    {:noreply,
     socket
     |> put_flash(:info, "User " <> user.name <> " is successfully deleted.")
     |> push_navigate(to: ~p"/users/")}
  end

  def handle_event("open_audit_log_modal", _params, socket) do
    {:noreply, assign(socket, show_audit_log_modal: true)}
  end

  def handle_event("close_audit_log_modal", _params, socket) do
    {:noreply, assign(socket, show_audit_log_modal: false)}
  end
end
