defmodule PhoexnipWeb.UserSettingsLive do
  use PhoexnipWeb, :live_view
  alias Phoexnip.Repo

  alias Phoexnip.Users.UserService

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-xl">
      <.header class="text-center mb-2">
        Change Password for {@current_user.name}
      </.header>

      <.simple_form
        for={@password_form}
        id="password_form"
        action={~p"/log_in?_action=password_updated"}
        method="post"
        class="flex w-full justify-center flex-wrap"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <div class="flex flex-wrap w-[75%] justify-center">
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            class="mt-4 w-full"
            required
          />

          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input
            field={@password_form[:password]}
            type="password"
            label="New password"
            class="mt-4 w-full"
            required
          />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
            class="mt-4 w-full"
          />
        </div>
        <:actions>
          <.button class="mt-4" phx-disable-with="Changing...">
            Change Password
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case UserService.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/account/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = UserService.change_user_email(user)
    password_changeset = UserService.change_user_password(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:page_title, "Change Password")

    {:ok, socket}
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> UserService.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case UserService.update_user_password(user, password, user_params) do
      {:ok, user} ->
        user = user |> Repo.preload(:user_roles)
        IO.inspect(user, label: "user")

        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "Change Password",
          # Entity ID
          user.id,
          # Action type
          "Update",
          # User who performed the action
          user,
          user.email,
          # New data (changes)
          user,
          # Previous data (empty since it's a new record)
          socket.assigns.current_user |> Repo.preload(:user_roles)
          # Metadata (example: user's IP)
        )

        password_form =
          user
          |> UserService.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
