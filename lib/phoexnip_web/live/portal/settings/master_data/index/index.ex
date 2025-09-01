defmodule PhoexnipWeb.MasterDataIndexLive.Index do
  use PhoexnipWeb, :live_view

  alias Phoexnip.UserRolesService

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    highest_permission_master_data = UserRolesService.fetch_level_two_user_permissions(user, "SET3")

    socket =
      if length(highest_permission_master_data) > 0 do
        get_url_for_first_master_data = highest_permission_master_data |> Enum.at(0)
        socket |> push_navigate(to: ~p"/" <> get_url_for_first_master_data.sitemap_url)
      else
        socket
        |> put_flash(:error, "You do not have access to this page.")
        |> redirect(to: ~p"/")
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
