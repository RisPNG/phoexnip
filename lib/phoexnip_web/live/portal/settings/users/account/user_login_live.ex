defmodule PhoexnipWeb.UserLoginLive do
  use PhoexnipWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Log in to account
      </.header>

      <.simple_form for={@form} id="login_form" action={~p"/log_in"} phx-update="ignore">
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <div class="w-full flex flex-wrap justify-between">
            <.input
              field={@form[:remember_me]}
              type="checkbox"
              label="Keep me logged in"
              class="pb-6 hidden"
            />
            <.link href={~p"/account/reset_password"} class="text-sm font-semibold pb-6">
              Forgot your password?
            </.link>
            <.button phx-disable-with="Logging in..." class="w-full">
              Log in <span aria-hidden="true">→</span>
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    socket = socket |> assign(:page_title, "Log in")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
