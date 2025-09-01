defmodule PhoexnipWeb.MasterDataCurrencyLive.Index do
  use PhoexnipWeb, :live_view

  alias Phoexnip.Masterdata.CurrencyService
  alias Phoexnip.Masterdata.Currency
  alias Phoexnip.UserRolesService

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    highest_permission_master_data = UserRolesService.fetch_level_two_user_permissions(user, "SET3")

    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        highest_permission_master_data,
        "SET3A",
        1
      )

    {:ok,
     socket
     |> assign(:master_data_permissions, highest_permission_master_data)
     |> assign(:current_section, "Currency")
     |> assign(:breadcrumb_first_segment, "Settings")
     |> assign(:breadcrumb_second_segment, "Master Data")
     |> assign(:breadcrumb_second_link, nil)
     |> assign(
       :breadcrumb_third_segment,
       "Currencies"
     )
     |> assign(:breadcrumb_third_link, "master_data/currencies")
     |> assign(:breadcrumb_fourth_segment, nil)
     |> assign(:show_audit_log_modal, false)
     |> assign(:breadcrumb_help_link, "master_data/currencies/usermanual")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        socket.assigns.master_data_permissions,
        "SET3A",
        4
      )

    socket
    |> assign(:page_title, "Edit Currency")
    |> assign(:currency, CurrencyService.get!(id))
    |> stream(:currency_collection, CurrencyService.list())
  end

  defp apply_action(socket, :new, _params) do
    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        socket.assigns.master_data_permissions,
        "SET3A",
        2
      )

    all_currency = CurrencyService.list()

    socket
    |> assign(:page_title, "New Currency")
    |> assign(:currency, %Currency{
      sort:
        if length(all_currency) == 0 do
          10
        else
          Enum.max_by(all_currency, & &1.sort).sort + 10
        end
    })
    |> stream(:currency_collection, all_currency)
  end

  defp apply_action(socket, :index, _params) do
    socket =
      Phoexnip.AuthenticationUtils.check_level_two_permissions(
        socket,
        socket.assigns.master_data_permissions,
        "SET3A",
        1
      )

    socket
    |> assign(:page_title, "Currencies")
    |> assign(:currency, nil)
    |> stream(:currency_collection, CurrencyService.list())
  end

  @impl true
  def handle_info(
        {PhoexnipWeb.MasterDataCurrencyLive.FormComponent, {:saved, _currency}},
        socket
      ) do
    {:noreply, stream(socket, :currency_collection, CurrencyService.list())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    currency = CurrencyService.get!(id)
    {:ok, _} = CurrencyService.delete(currency)

    Phoexnip.AuditLogService.create_audit_log(
      # Entity type
      "Currency",
      # Entity ID
      currency.id,
      # Action type
      "delete",
      # User who performed the action
      socket.assigns.current_user,
      currency.code,
      # New data (changes)
      %{},
      # Previous data (empty since it's a new record)
      currency
      # Metadata (example: user's IP)
    )

    {:noreply, stream(socket, :currency_collection, CurrencyService.list())}
  end

  def handle_event(
        "open_audit_log_modal",
        %{"id" => id, "code" => code, "inserted_at" => inserted_at},
        socket
      ) do
    audit_log_data = %{
      id: id,
      code: code,
      inserted_at:
        case DateTime.from_iso8601(inserted_at) do
          {:ok, datetime, _offset} ->
            datetime

          {:error, _reason} ->
            # Handle error case or set a default value if needed
            nil
        end
    }

    socket =
      socket
      |> assign(:audit_log_data, audit_log_data)
      |> assign(:show_audit_log_modal, true)
      |> stream(:currency_collection, CurrencyService.list())

    {:noreply, socket}
  end

  def handle_event("close_audit_log_modal", _params, socket) do
    {:noreply,
     assign(socket, show_audit_log_modal: false)
     |> stream(:currency_collection, CurrencyService.list())}
  end
end
