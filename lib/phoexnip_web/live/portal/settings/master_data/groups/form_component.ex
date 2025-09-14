defmodule PhoexnipWeb.MasterDataGroupsLive.FormComponent do
  use PhoexnipWeb, :live_component

  alias Phoexnip.ServiceUtils

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage groups records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="groups-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <%!-- Empty input to remove auto selection when opening modal --%>
        <input type="text" class="!opacity-0 !absolute" />
        <.input field={@form[:sort]} type="number" label="Sort" />
        <.input field={@form[:code]} type="text" label="Code" />
        <.input field={@form[:name]} type="text" label="Name" />
        <:actions>
          <.button phx-disable-with="Saving..." class="flex align-center">
            <svg
              class="w-6 h-6 me-1"
              xmlns="http://www.w3.org/2000/svg"
              height="48px"
              viewBox="0 -960 960 960"
              width="24px"
              fill="currentColor"
            >
              <path d="M800-663.08v438.46q0 27.62-18.5 46.12Q763-160 735.38-160H224.62q-27.62 0-46.12-18.5Q160-197 160-224.62v-510.76q0-27.62 18.5-46.12Q197-800 224.62-800h438.46L800-663.08ZM760-646 646-760H224.62q-10.77 0-17.7 6.92-6.92 6.93-6.92 17.7v510.76q0 10.77 6.92 17.7 6.93 6.92 17.7 6.92h510.76q10.77 0 17.7-6.92 6.92-6.93 6.92-17.7V-646ZM480-298.46q33.08 0 56.54-23.46T560-378.46q0-33.08-23.46-56.54T480-458.46q-33.08 0-56.54 23.46T400-378.46q0 33.08 23.46 56.54T480-298.46ZM270.77-569.23h296.92v-120H270.77v120ZM200-646v446-560 114Z" />
            </svg>
            Save
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{groups: groups} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(ServiceUtils.change(groups))
     end)}
  end

  @impl true
  def handle_event("validate", %{"groups" => groups_params}, socket) do
    changeset = ServiceUtils.change(socket.assigns.groups, groups_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"groups" => groups_params}, socket) do
    IO.inspect(groups_params, label: "groups_params")
    save(socket, socket.assigns.action, groups_params)
  end

  defp save(socket, :edit, groups_params) do
    case ServiceUtils.update(socket.assigns.groups, groups_params) do
      {:ok, groups} ->
        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "Groups",
          # Entity ID
          groups.id,
          # Action type
          "update",
          # User who performed the action
          socket.assigns.current_user,
          groups.code,
          # New data (changes)
          groups,
          # Previous data (empty since it's a new record)
          socket.assigns.groups
          # Metadata (example: user's IP)
        )

        notify_parent({:saved, groups})

        {:noreply,
         socket
         |> put_flash(:info, "Groups updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save(socket, :new, groups_params) do
    case ServiceUtils.create(Phoexnip.Masterdata.Groups, groups_params) do
      {:ok, groups} ->
        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "Groups",
          # Entity ID
          groups.id,
          # Action type
          "create",
          # User who performed the action
          socket.assigns.current_user,
          groups.code,
          # New data (changes)
          groups,
          # Previous data (empty since it's a new record)
          %{}
          # Metadata (example: user's IP)
        )

        notify_parent({:saved, groups})

        {:noreply,
         socket
         |> put_flash(:info, "Groups created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
