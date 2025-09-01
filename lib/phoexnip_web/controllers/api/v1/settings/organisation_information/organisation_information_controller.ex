defmodule PhoexnipWeb.OrganisationInformationController do
  @moduledoc """
  Manages HTTP API endpoints for Organisation Information in the Phoexnip application.

  This controller provides actions to:
    - retrieve the current organisation information (`index/2`)
    - create new organisation information (`create/2`)
    - update existing organisation information (`update/2`)

  All actions enforce API permission checks and return JSON responses.
  """

  use PhoexnipWeb, :controller
  use PhoenixSwagger

  alias Phoexnip.Settings.OrganisationInfo
  alias Phoexnip.Settings.OrganisationInfoService

  @doc """
  Retrieves the organisation information record.

  ## Parameters

    - conn: the connection struct.
    - _params: request parameters (ignored).

  ## Returns

    - Updated connection with JSON response containing the organisation information.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn.assigns.current_user, "SET4", 1) ==
         false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    organisation_info = OrganisationInfoService.get_organisation_info()

    render(conn, :index, organisation_info: organisation_info)
  end

  @doc """
  Creates a organisation information record if none exists.

  ## Parameters

    - conn: the connection struct.
    - _: request parameters (ignored).

  ## Returns

    - Updated connection with JSON response of the newly created organisation information,
      or a conflict/error status if creation is not allowed or fails.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn.assigns.current_user, "SET4", 2) ==
         false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    organisation_info = OrganisationInfoService.get_organisation_info()

    if organisation_info.id != nil do
      conn
      |> put_status(:conflict)
      |> json(%{
        error: "Failed to create organisation information as it already exists. Use PUT instead"
      })
    else
      # Extracting the user parameters from the body_params of the connection
      params = conn.body_params["organisation_info"] || conn.body_params

      case OrganisationInfoService.create(params) do
        {:ok, %OrganisationInfo{} = new_organisation_info} ->
          Phoexnip.AuditLogService.create_audit_log(
            # Entity type
            "Organisation Information - API",
            # Entity ID
            new_organisation_info.id,
            # Action type
            "create",
            # User who performed the action
            conn.assigns.current_user,
            organisation_info.name,
            # New data (changes)
            new_organisation_info,
            # Previous data (empty since it's a new record)
            %{}
          )

          conn
          |> put_status(:ok)
          |> render(:index, organisation_info: new_organisation_info)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            error: "Failed to create Organisation Information",
            details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
          })
      end
    end
  end

  @doc """
  Updates the existing organisation information record.

  ## Parameters

    - conn: the connection struct.
    - _: request parameters (ignored; update data read from conn.body_params).

  ## Returns

    - Updated connection with JSON response of the updated organisation information,
      or a not found/error status if the record is missing or update fails.
  """
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, _) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn.assigns.current_user, "SET4", 4) ==
         false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    master_data = OrganisationInfoService.get_organisation_info()

    case OrganisationInfoService.update(master_data, conn.body_params) do
      {:ok, %OrganisationInfo{} = updated_master_data} ->
        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "Organisation Information - API",
          # Entity ID
          updated_master_data.id,
          # Action type
          "update",
          # User who performed the action
          conn.assigns.current_user,
          updated_master_data.name,
          # New data (changes)
          updated_master_data,
          # Previous data (empty since it's a new record)
          master_data
        )

        conn
        |> put_status(:ok)
        |> render(:index, organisation_info: updated_master_data)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Failed to update Organisation Information",
          details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
        })
    end
  end

  @doc false
  swagger_path :index do
    get("/api/v1/organisation_information")
    description("Retrieve organisation information.")
    summary("Get Organisation Information")
    produces("application/json")
    tag("Organisation Information")
    security([%{"api_key" => []}])

    response(200, "Organisation information retrieved successfully", Schema.ref(:OrganisationInformation))
    response(401, "Unauthorized: Not enough permissions!")
    response(403, "Forbidden: Your API Key is no longer valid")
  end

  @doc false
  swagger_path :create do
    post("/api/v1/organisation_information")
    description("Create organisation information. Fails if the information already exists.")
    summary("Create Organisation Information")
    produces("application/json")
    consumes("application/json")
    tag("Organisation Information")
    security([%{"api_key" => []}])

    parameter(:body, :body, Schema.ref(:OrganisationInformation), "Organisation Information parameters",
      required: true
    )

    response(200, "Organisation information created successfully", Schema.ref(:OrganisationInformation))
    response(401, "Unauthorized: Not enough permissions!")
    response(403, "Forbidden: Your API Key is no longer valid")
    response(409, "Conflict: Organisation information already exists. Use PUT instead.")
    response(422, "Unprocessable Entity: Validation errors")
  end

  @doc false
  swagger_path :update do
    put("/api/v1/organisation_information/")
    description("Update existing organisation information.")
    summary("Update Organisation Information")
    produces("application/json")
    consumes("application/json")
    tag("Organisation Information")
    security([%{"api_key" => []}])

    parameter(:id, :path, :integer, "ID of the organisation information", required: true)

    parameter(
      :body,
      :body,
      Schema.ref(:OrganisationInformation),
      "Updated Organisation Information parameters",
      required: true
    )

    response(200, "Organisation information updated successfully", Schema.ref(:OrganisationInformation))
    response(401, "Unauthorized: Not enough permissions!")
    response(403, "Forbidden: Your API Key is no longer valid")
    response(404, "Not Found: Organisation information not found")
    response(422, "Unprocessable Entity: Validation errors")
  end

  @doc """
  Returns the Swagger schema definitions for Organisation Information and related types.

  ## Returns

    - A map of Swagger schema definitions.
  """
  @spec swagger_definitions() :: map()
  def swagger_definitions do
    %{
      Address:
        swagger_schema do
          title("Address")
          description("Schema for an address entry in the application.")
          property(:guid, :string, "Unique address identifier")
          property(:attn, :string, "Attention to")
          property(:line1, :string, "Address line 1")
          property(:line2, :string, "Address line 2")
          property(:line3, :string, "Address line 3")
          property(:postcode, :string, "Postal code")
          property(:city, :string, "City")
          property(:state, :string, "State")
          property(:country, :string, "Country")
          property(:category, :string, "Category of the address")
          property(:sequence, :integer, "Sequence order for the address")
          property(:inserted_at, :string, "Date and time when the address was created")
          property(:updated_at, :string, "Date and time when the address was last updated")
        end,
      OrganisationInformation:
        swagger_schema do
          title("Organisation Information")
          description("Parameters for creating or updating organisation information.")
          property(:name, :string, "Organisation name", required: true)
          property(:registration_number, :string, "Registration number", required: true)
          property(:gst_number, :string, "GST number")
          property(:socso_number, :string, "SOCSO number")
          property(:pcb_number, :string, "PCB number")
          property(:phone, :string, "Organisation phone number")
          property(:fax, :string, "Organisation fax number")
          property(:website, :string, "Organisation website")
          property(:email, :string, "Organisation email")
          property(:currency, :string, "Currency code")
          property(:address, Schema.array(:Address), "List of organisation addresses")
        end
    }
  end
end
