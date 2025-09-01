defmodule PhoexnipWeb.MasterDataCurrencyLive.UserManual do
  use PhoexnipWeb, :live_view

  @impl true
  def mount(_, _, socket) do
    user = socket.assigns.current_user

    highest_permission_master_data =
      Phoexnip.UserRolesService.fetch_level_two_user_permissions(user, "SET3")

    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        highest_permission_master_data,
        "SET3A",
        1
      )

    {:ok,
     socket
     |> assign(:breadcrumb_first_segment, "Settings")
     |> assign(:breadcrumb_second_segment, "Master Data")
     |> assign(:breadcrumb_second_link, nil)
     |> assign(:breadcrumb_third_link, "master_data/currencies")
     |> assign(
       :breadcrumb_third_segment,
       "Currencies"
     )
     |> assign(:breadcrumb_fourth_segment, "User Manual")
     |> assign(:current_section, "create")}
  end

  @impl true
  def handle_event("change_section", %{"section" => section}, socket) do
    {:noreply, assign(socket, current_section: section)}
  end
end
