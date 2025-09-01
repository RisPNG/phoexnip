defmodule PhoexnipWeb.Home.Index do
  use PhoexnipWeb, :live_view
  @moduledoc """
  Home page LiveView for the template. Sets up breadcrumbs and
  enforces basic page permissions when a user has permissions assigned.
  """

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if socket.assigns.permissions != [] do
        Phoexnip.AuthenticationUtils.check_page_permissions(socket, "H", 1)
      else
        socket
      end

    {:ok,
     socket
     |> assign(:breadcrumb_first_segment, nil)
     |> assign(:breadcrumb_second_segment, nil)
     |> assign(:breadcrumb_second_link, nil)
     |> assign(
       :breadcrumb_third_segment,
       nil
     )
     |> assign(:breadcrumb_fourth_segment, nil)
     |> assign(:breadcrumb_help_link, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket =
      if socket.assigns.permissions != [] do
        Phoexnip.AuthenticationUtils.check_page_permissions(socket, "H", 1)
      else
        socket
      end

    socket
    |> assign(:page_title, "Home")
    |> assign(:breadcrumb_first_segment, nil)
    |> assign(:breadcrumb_second_segment, nil)
    |> assign(:breadcrumb_second_link, nil)
    |> assign(
      :breadcrumb_third_segment,
      nil
    )
    |> assign(:breadcrumb_fourth_segment, nil)
    |> assign(:breadcrumb_help_link, nil)
  end
end
