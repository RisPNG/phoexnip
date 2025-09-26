defmodule PhoexnipWeb.OrganisationInfoLive.New do
  use PhoexnipWeb, :live_view

  @moduledoc """
  LiveView for creating and editing Organisation Information.

  Provides a single form for maintaining core organisation profile details and
  addresses, with dynamic add/remove and resequencing per address category.
  """

  alias Phoexnip.Settings.OrganisationInfo
  alias Phoexnip.ServiceUtils
  alias Phoexnip.SearchUtils
  alias Phoexnip.Masterdata.Currencies

  @impl true
  def mount(_params, _session, socket) do
    socket = Phoexnip.AuthenticationUtils.check_page_permissions(socket, "SET4", 4)

    organisation_information = fetch_organisation_info()
    changeset = ServiceUtils.change(organisation_information)

    currency =
      ServiceUtils.list_ordered(Currencies, asc: :sort) |> Enum.map(&{"#{&1.name}", &1.code})

    {:ok,
     socket
     |> assign(:page_title, "Organisation Information")
     |> assign(:currency, currency)
     |> assign(:organisation_info, organisation_information)
     |> assign(:form, changeset)
     |> assign(:breadcrumb_first_segment, "Settings")
     |> assign(:breadcrumb_second_segment, "Organisation Information")
     |> assign(:breadcrumb_second_link, "organisation_information")
     |> assign(
       :breadcrumb_third_segment,
       nil
     )
     |> assign(:breadcrumb_fourth_segment, nil)
     |> assign(:breadcrumb_help_link, "organisation_information/user_manual")}
  end

  @impl true
  def handle_event("save", %{"organisation_info" => params}, socket) do
    organisation_info = socket.assigns.organisation_info

    if organisation_info.id != nil do
      case ServiceUtils.update(organisation_info, params) do
        {:ok, new_organisation_info} ->
          # Create the audit log after customer creation
          Phoexnip.AuditLogService.create_audit_log(
            # Entity type
            "Organisation Information",
            # Entity ID
            new_organisation_info.id,
            # Action type
            "update",
            # User who performed the action
            socket.assigns.current_user,
            organisation_info.name,
            # New data (changes)
            new_organisation_info,
            # Previous data (empty since it's a new record)
            organisation_info
            # Metadata (example: user's IP)
          )

          {:noreply,
           socket
           |> put_flash(:info, "Organisation information is successfully updated.")
           |> push_navigate(to: ~p"/organisation_information/")}

        {:error, errors} ->
          {:noreply, assign(socket, :form, errors)}
      end
    else
      # Save the user first to ensure unique constrained is honored.
      case ServiceUtils.create(OrganisationInfo, params) do
        {:ok, organisation_info} ->
          Phoexnip.AuditLogService.create_audit_log(
            # Entity type
            "Organisation Information",
            # Entity ID
            organisation_info.id,
            # Action type
            "create",
            # User who performed the action
            socket.assigns.current_user,
            organisation_info.name,
            # New data (changes)
            organisation_info,
            # Previous data (empty since it's a new record)
            %{}
            # Metadata (example: user's IP)
          )

          {:noreply,
           socket
           |> put_flash(:info, "Organisation information is successfully created.")
           |> push_navigate(to: ~p"/organisation_information/")}

        {:error, errors} ->
          {:noreply, assign(socket, :form, errors)}
      end
    end
  end

  def handle_event("validate", %{"organisation_info" => params}, socket) do
    if socket.assigns.organisation_info.id != nil do
      changeset =
        socket.assigns.organisation_info
        |> ServiceUtils.change(params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, form: changeset)}
    else
      changeset =
        %OrganisationInfo{}
        |> ServiceUtils.change(params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, form: changeset)}
    end
  end

  def handle_event("add_address", %{"category" => category}, socket) do
    customer_changeset = socket.assigns.form
    # some special sauce
    customer = Ecto.Changeset.apply_changes(customer_changeset)

    max_sequence =
      customer.address
      |> Enum.filter(fn addr -> addr.category == category end)
      |> Enum.map(& &1.sequence)
      # default to 0 if no addresses found
      |> Enum.max(fn -> 0 end)

    new_address = %Phoexnip.Address{
      category: category,
      guid: Ecto.UUID.generate(),
      sequence: max_sequence + 1
    }

    updated_customer = %{
      customer
      | address: customer.address ++ [new_address]
    }

    {:noreply, assign(socket, :form, ServiceUtils.change(updated_customer))}
  end

  def handle_event("remove_address", %{"guid" => guid}, socket) do
    customer_changeset = socket.assigns.form
    customer = Ecto.Changeset.apply_changes(customer_changeset)

    # Remove the address with the matching guid
    updated_addresses =
      customer.address
      |> Enum.reject(fn addr -> addr.guid == guid end)

    # Find the category of the removed address, if any
    category =
      customer.address
      |> Enum.find(fn addr -> addr.guid == guid end)
      |> case do
        nil -> nil
        removed_address -> removed_address.category
      end

    # Resequence only the addresses of the same category
    resequenced_addresses =
      updated_addresses
      |> Enum.filter(&(&1.category == category))
      |> Enum.with_index(1)
      |> Enum.map(fn {addr, index} ->
        %{addr | sequence: index}
      end)

    # Get addresses not in the same category
    other_addresses =
      updated_addresses
      |> Enum.reject(&(&1.category == category))

    # Merge the resequenced addresses with the other addresses
    final_addresses = other_addresses ++ resequenced_addresses

    # Update the customer with the final addresses
    updated_customer = %{customer | address: final_addresses}

    # Assign the updated changeset back to the socket
    {:noreply, assign(socket, :form, ServiceUtils.change(updated_customer))}
  end

  @impl true
  def handle_event("live_select_change", %{"id" => id} = params, socket) do
    text = Map.get(params, "text", "")

    options =
      cond do
        String.starts_with?(id, "live-single-select-country") ->
          Phoexnip.SearchUtils.search(
            args: %{code: text, name: text},
            pagination: %{
              page: 1,
              per_page: 20
            },
            module: Phoexnip.Masterdata.Countries,
            use_or: true
          )
          |> Map.get(:entries)
          |> Enum.map(&{"#{&1.name}", &1.name})

        true ->
          []
      end

    send_update(LiveSelect.Component, id: id, options: options)

    {:noreply, socket}
  end

  defp fetch_organisation_info do
    result =
      SearchUtils.search(
        args: %{},
        pagination: %{page: 1, per_page: 1},
        module: OrganisationInfo,
        preload: [:address]
      )

    case result.entries do
      [info | _] ->
        info

      [] ->
        %OrganisationInfo{
          address: [
            %Phoexnip.Address{guid: Ecto.UUID.generate(), category: "BILLING", sequence: 1},
            %Phoexnip.Address{guid: Ecto.UUID.generate(), category: "DELIVERY", sequence: 1}
          ]
        }
    end
  end
end
