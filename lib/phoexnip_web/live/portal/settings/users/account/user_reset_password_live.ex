defmodule PhoexnipWeb.UserResetPasswordLive do
  use PhoexnipWeb, :live_view
  alias Phoexnip.Users.UserService
  alias Phoexnip.Repo

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Reset Password</.header>

      <.simple_form
        for={@form}
        id="reset_password_form"
        phx-submit="reset_password"
        phx-change="validate"
      >
        <.error :if={@form.errors != []}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input field={@form[:password]} type="password" label="New password" required />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          required
          class="mt-2"
        />
        <:actions>
          <.button phx-disable-with="Resetting..." class="w-[49%] mt-2">Reset Password</.button>
          <.link
            class="w-[49%] flex mt-2 justify-center rounded-lg py-2 px-3 font-semibold leading-6 border border-f0f0f0 hover:bg-amber-600 focus:bg-amber-600"
            href={~p"/log_in"}
          >
            Log in
          </.link>
        </:actions>
      </.simple_form>

      <p class="text-center text-sm mt-4"></p>
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_user_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{user: user} ->
          UserService.change_user_password(user)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case UserService.reset_user_password(socket.assigns.user, user_params) do
      {:ok, user} ->
        user = user |> Repo.preload(:user_roles)

        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "Update User Password",
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
          socket.assigns.user |> Repo.preload(:user_roles)
          # Metadata (example: user's IP)
        )

        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/log_in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = UserService.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = UserService.get_user_by_reset_password_token(token) do
      assign(socket, user: user, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
