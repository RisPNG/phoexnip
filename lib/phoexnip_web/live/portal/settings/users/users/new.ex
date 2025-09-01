defmodule PhoexnipWeb.UsersLive.New do
  use PhoexnipWeb, :live_view
  @moduledoc """
  LiveView for creating and updating users, including role assignment and avatar upload.

  - New mode: initializes empty user with available roles.
  - Edit mode: loads the selected user and merges existing roles.
  - Validates input via changesets and records audit logs on save.
  """

  alias Phoexnip.Users.UserService
  alias Phoexnip.Users.User

  @impl true
  def mount(params, _session, socket) do
    if params == %{} do
      socket = Phoexnip.AuthenticationUtils.check_page_permissions(socket, "SET1", 2)

      roles = Phoexnip.RolesService.list(preload: false)

      user_roles =
        Enum.map(roles, fn role ->
          %{
            role_id: role.id,
            role_name: role.name,
            belongs_in_role: false
          }
        end)

      user = %User{}
      changeset = UserService.change(user, %{user_roles: user_roles})

      {:ok,
       socket
       |> assign(:page_title, "New User")
       |> assign(:image_url, Phoexnip.ImageUtils.image_for(%User{}))
       |> assign(:user_id, 0)
       |> assign(:user, user)
       |> assign(:form, changeset)
       |> assign(:uploaded_files, [])
       |> assign(:auto_upload, true)
       |> assign(:breadcrumb_first_segment, "Settings")
       |> assign(:breadcrumb_second_segment, "Users")
       |> assign(:breadcrumb_second_link, "users")
       |> assign(
         :breadcrumb_third_segment,
         "New"
       )
       |> assign(:breadcrumb_fourth_segment, nil)
       |> assign(:breadcrumb_help_link, "users/user_manual")
       |> allow_upload(:avatar, accept: ~w(.jpg .jpeg .png .gif), max_entries: 1)}
    else
      socket = Phoexnip.AuthenticationUtils.check_page_permissions(socket, "SET1", 4)

      user = UserService.get!(String.to_integer(params["id"]))

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

      {:ok,
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
         "Edit"
       )
       |> assign(:breadcrumb_fourth_segment, "" <> user.name <> " - " <> user.email)
       |> assign(:breadcrumb_help_link, "users/user_manual")
       |> allow_upload(:avatar,
         accept: ~w(.jpg .jpeg .png .gif),
         max_entries: 1,
         auto_upload: true
       )}
    end
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    old_user = socket.assigns.user

    # prepare the socket because redirect seems to do strange stuff when using
    uploaded_file =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _ ->
        case Phoexnip.ImageUtils.save_image_from_path(
               path,
               old_user.image_url
             ) do
          {:ok, image_path} ->
            {:ok, image_path}

          {:error, _} ->
            {:ok, ""}
        end
      end)

    params =
      case uploaded_file do
        [link] -> Map.put(params, "image_url", link)
        _ -> params
      end

    if old_user.id == nil do
      # Save the user first to ensure unique constrained is honored.
      case UserService.create_user(params) do
        {:ok, user} ->
          Phoexnip.AuditLogService.create_audit_log(
            # Entity type
            "User",
            # Entity ID
            user.id,
            # Action type
            "create",
            # User who performed the action
            socket.assigns.current_user,
            user.email,
            # New data (changes)
            user,
            # Previous data (empty since it's a new record)
            %{}
            # Metadata (example: user's IP)
          )

          # redirects correctly if no image is uploaded.
          # redirects then reloads the page.
          {:noreply,
           socket
           |> put_flash(:info, "User " <> user.name <> " is successfully created.")
           |> push_navigate(to: ~p"/users/#{user.id}")}

        {:error, errors} ->
          {:noreply, assign(socket, :form, errors)}
      end
    else
      # Save the user first to ensure unique constrain is honored.
      case UserService.update_user(socket.assigns.user, params) do
        {:ok, user} ->
          # Create the audit log after customer creation
          Phoexnip.AuditLogService.create_audit_log(
            # Entity type
            "User",
            # Entity ID
            user.id,
            # Action type
            "update",
            # User who performed the action
            socket.assigns.current_user,
            user.email,
            # New data (changes)
            user,
            # Previous data (empty since it's a new record)
            old_user
            # Metadata (example: user's IP)
          )

          # redirects correctly if no image is uploaded.
          # redirects then reloads the page.
          {:noreply,
           socket
           |> put_flash(:info, "User " <> user.name <> " is successfully updated.")
           |> push_navigate(to: ~p"/users/#{user.id}")}

        {:error, errors} ->
          {:noreply, assign(socket, :form, errors)}
      end
    end
  end

  def handle_event("validate", %{"user" => params}, socket) do
    if socket.assigns.user.id == nil do
      changeset =
        %User{}
        |> UserService.change(params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, form: changeset)}
    else
      changeset =
        %User{}
        |> UserService.change_update(params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, form: changeset)}
    end
  end

  @impl true
  def handle_event("live_select_change", %{"id" => id} = params, socket) do
    text = Map.get(params, "text", "")

    search_text = if text == "*", do: "", else: text

    options =
      cond do
        String.starts_with?(id, "live-single-select-group") ->
          Phoexnip.SearchUtils.search(
            args: %{
              code: search_text,
              name: search_text
            },
            module: Phoexnip.Masterdata.Groups,
            use_or: true
          )
          |> Map.get(:entries)
          |> Enum.map(&{&1.name, &1.name})
          |> (fn result ->
                if text == "*" do
                  result
                else
                  Enum.take(result, 5)
                end
              end).()

        String.starts_with?(id, "live-single-select-customer") ->
          Phoexnip.SearchUtils.search(
            args: %{
              code: search_text,
              name: search_text
            },
            module: Phoexnip.Sales.Customers,
            use_or: true
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.code} - #{&1.name}", &1.code})

        String.starts_with?(id, "live-single-select-supplier") ->
          Phoexnip.SearchUtils.search(
            args: %{
              code: search_text,
              name: search_text,
              ext_supp_code: search_text
            },
            module: Phoexnip.Purchase.Suppliers,
            use_or: true
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.code} / #{&1.ext_supp_code} - #{&1.name}", &1.code})

        String.starts_with?(id, "live-single-select-location") ->
          Phoexnip.SearchUtils.search(
            args: %{
              code: search_text,
              name: search_text
            },
            module: Phoexnip.Masterdata.Countries,
            use_or: true
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.code} - #{&1.name}", &1.code})

        true ->
          []
      end

    send_update(LiveSelect.Component, id: id, options: options)

    {:noreply, socket}
  end

  defp error_to_string(:too_large),
    do: "The size of the image is to big. Please keep the file size under 8mb"

  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
