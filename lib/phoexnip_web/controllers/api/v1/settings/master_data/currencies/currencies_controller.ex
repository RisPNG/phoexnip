defmodule PhoexnipWeb.MasterDataCurrenciesController do
  @moduledoc """
  Handles HTTP API endpoints for Master Data Currencies in the Phoexnip application.

  This controller provides actions to:
    - list all currency (`index/2`)
    - show a currency by ID (`show/2`)
    - create a new currency (`create/2`)
    - update an existing currency (`update/2`)
    - delete a currency (`delete/2`)
    - provide Swagger schema definitions (`swagger_definitions/0`)

  All actions enforce API permission checks and return JSON responses.
  """

  use PhoexnipWeb, :controller
  use PhoenixSwagger

  alias Phoexnip.Masterdata.Currencies
  alias Phoexnip.ServiceUtils

  @doc """
  Renders a list of all currency.

  ## Parameters

    - conn: the connection struct.
    - _params: request parameters (ignored).

  ## Returns

    - Updated connection with JSON response containing the list of currency.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3A",
         1
       ) ==
         false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    masterdatas = ServiceUtils.list_ordered(Currencies, [asc: :sort])
    render(conn, :index, masterdatas: masterdatas)
  end

  @doc """
  Retrieves and renders a currency by ID.

  ## Parameters

    - conn: the connection struct.
    - %{"id" => id}: map with string "id" key identifying the currency.

  ## Returns

    - Updated connection with JSON response of the currency or a 404 error.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3A",
         1
       ) ==
         false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case ServiceUtils.get(Currencies, id) do
      %Currencies{} = colour ->
        render(conn, :show, masterdata: colour)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Not found"})
    end
  end

  @doc """
  Creates a new currency from the request body.

  ## Parameters

    - conn: the connection struct.
    - _: ignored; currency attributes are read from conn.body_params.

  ## Returns

    - Updated connection with JSON response of the created currency or error details.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3A",
         2
       ) ==
         false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    # Extracting the user parameters from the body_params of the connection
    params = conn.body_params["currency"] || conn.body_params

    case ServiceUtils.create(Currencies, params) do
      {:ok, %Currencies{} = masterdata} ->
        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "Currencies - API",
          # Entity ID
          masterdata.id,
          # Action type
          "create",
          # User who performed the action
          conn.assigns.current_user,
          masterdata.code,
          # New data (changes)
          masterdata,
          # Previous data (empty since it's a new record)
          %{}
        )

        conn
        |> put_status(:ok)
        |> render(:show, masterdata: masterdata)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Failed to create Currencies",
          details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
        })
    end
  end

  @doc """
  Updates an existing currency by ID.

  ## Parameters

    - conn: the connection struct.
    - %{"id" => id}: map with string "id" key.

  ## Returns

    - Updated connection with JSON response of the updated currency or error details.
  """
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id}) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3A",
         4
       ) ==
         false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    IO.inspect(conn.body_params)

    case ServiceUtils.get(Currencies, id) do
      %Currencies{} = masterdata ->
        case ServiceUtils.update(masterdata, conn.body_params) do
          {:ok, %Currencies{} = updated_masterdata} ->
            Phoexnip.AuditLogService.create_audit_log(
              # Entity type
              "Currencies - API",
              # Entity ID
              updated_masterdata.id,
              # Action type
              "update",
              # User who performed the action
              conn.assigns.current_user,
              updated_masterdata.code,
              # New data (changes)
              updated_masterdata,
              # Previous data (empty since it's a new record)
              masterdata
            )

            conn
            |> put_status(:ok)
            |> render(:show, masterdata: updated_masterdata)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to update Currencies",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Currencies not found"})
    end
  end

  @doc """
  Deletes a currency by ID.

  ## Parameters

    - conn: the connection struct.
    - %{"id" => id}: map with string "id" key.

  ## Returns

    - Updated connection with no content response or error details.
  """
  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3A",
         8
       ) ==
         false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case ServiceUtils.get(Currencies, id) do
      %Currencies{} = masterdata ->
        case ServiceUtils.delete(masterdata) do
          {:ok, _} ->
            Phoexnip.AuditLogService.create_audit_log(
              # Entity type
              "Currencies - API",
              # Entity ID
              masterdata.id,
              # Action type
              "delete",
              # User who performed the action
              conn.assigns.current_user,
              masterdata.code,
              # New data (changes)
              %{},
              # Previous data (empty since it's a new record)
              masterdata
            )

            conn
            |> send_resp(:no_content, "")

          {:error, error} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to delete Currencies",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(error)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Currencies not found"})
    end
  end

  @doc """
  Returns the Swagger schema definitions for Currencies objects.

  ## Returns

    - A map of Swagger schema definitions.
  """
  @spec swagger_definitions() :: map()
  def swagger_definitions do
    %{
      Currencies:
        swagger_schema do
          title("Masterdata - Currencies")
          description("Details of Currencies")

          properties do
            code(:string, "Code of the Currencies", required: true)
            name(:string, "Name of the Currencies", required: true)
            sort(:integer, "Sort of the Currencies", required: true)
          end
        end
    }
  end

  @doc false
  swagger_path :index do
    get("/api/v1/master_data/currencies")
    summary("List of Currencies")
    description("Fetch a paginated list of Currencies.")
    produces("application/json")
    security([%{"api_key" => []}])

    response(200, "OK", Schema.ref(:Currencies))
    response(401, "Not Authorized")
    response(403, "Forbidden")
  end

  @doc false
  swagger_path :show do
    get("/api/v1/master_data/currencies/{id}")
    summary("Show Currencies")
    description("Fetch a Currencies by ID")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "Currencies ID", required: true)
    end

    response(200, "OK", Schema.ref(:Currencies))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  @doc false
  swagger_path :create do
    post("/api/v1/master_data/currencies/")
    summary("Create Currencies")
    description("Create a new Currencies.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Currencies), "Currencies attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Currencies))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :update do
    put("/api/v1/master_data/currencies/{id}")
    summary("Update Currencies")
    description("Update a Currencies.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Currencies), "Currencies attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Currencies))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/v1/master_data/currencies/{id}")
    summary("Delete Currencies")
    description("Delete a Currencies by ID.")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "Currencies ID", required: true)
    end

    response(204, "No Content")
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end
end
