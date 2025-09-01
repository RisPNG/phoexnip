defmodule PhoexnipWeb.UsersLive.UserManual do
  use PhoexnipWeb, :live_view

  @impl true
  def mount(_, _, socket) do
    {:ok,
     socket
     |> Phoexnip.AuthenticationUtils.check_page_permissions("SET1", 1)
     |> assign(:breadcrumb_first_segment, "Settings")
     |> assign(:breadcrumb_second_segment, "Users")
     |> assign(:breadcrumb_second_link, "users")
     |> assign(
       :breadcrumb_third_segment,
       "User Manual"
     )
     |> assign(:breadcrumb_fourth_segment, nil)
     |> assign(:current_section, "search")}
  end

  @impl true
  def handle_event("change_section", %{"section" => section}, socket) do
    {:noreply, assign(socket, current_section: section)}
  end
end
