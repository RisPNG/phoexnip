defmodule PhoexnipWeb.UserForgotPasswordLive do
  use PhoexnipWeb, :live_view

  alias Phoexnip.Users.UserService

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Forgot your password?
        <:subtitle>We'll send a password reset link to your inbox</:subtitle>
      </.header>

      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-[49%]">
            Reset
          </.button>
          <.link
            class="w-[49%] flex justify-center rounded-lg py-2 px-3 font-semibold leading-6 border border-f0f0f0 hover:bg-amber-600 focus:bg-amber-600"
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

  def mount(_params, _session, socket) do
    socket = socket |> assign(:page_title, "Forgot password")
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = UserService.get_user_by_email(email) do
      UserService.deliver_user_reset_password_instructions(
        user,
        &url(~p"/account/reset_password/#{&1}")
      )

      Phoexnip.AuditLogService.create_audit_log(
        # Entity type
        "Password Reset Request",
        # Entity ID
        -1,
        # Action type
        "create",
        # User who performed the action
        %{:id => -1, :name => "unknown"},
        email,
        # New data (changes)
        %{"email" => email},
        # Previous data (empty since it's a new record)
        %{}
        # Metadata (example: user's IP)
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
