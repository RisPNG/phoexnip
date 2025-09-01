defmodule PhoexnipWeb.MasterDataCurrencyController do
  @moduledoc """
  Handles HTTP API endpoints for Master Data Currency in the Phoexnip application.

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

  alias Phoexnip.Masterdata.Currency
  alias Phoexnip.Masterdata.CurrencyService

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

    masterdatas = CurrencyService.list()
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

    case CurrencyService.get(id) do
      %Currency{} = colour ->
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

    case CurrencyService.create(params) do
      {:ok, %Currency{} = masterdata} ->
        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "Currency - API",
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
          error: "Failed to create Currency",
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

    case CurrencyService.get(id) do
      %Currency{} = masterdata ->
        case CurrencyService.update(masterdata, conn.body_params) do
          {:ok, %Currency{} = updated_masterdata} ->
            Phoexnip.AuditLogService.create_audit_log(
              # Entity type
              "Currency - API",
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
              error: "Failed to update Currency",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Currency not found"})
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

    case CurrencyService.get(id) do
      %Currency{} = masterdata ->
        case CurrencyService.delete(masterdata) do
          {:ok, _} ->
            Phoexnip.AuditLogService.create_audit_log(
              # Entity type
              "Currency - API",
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
              error: "Failed to delete Currency",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(error)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Currency not found"})
    end
  end

  @doc """
  Returns the Swagger schema definitions for Currency objects.

  ## Returns

    - A map of Swagger schema definitions.
  """
  @spec swagger_definitions() :: map()
  def swagger_definitions do
    %{
      Currency:
        swagger_schema do
          title("Masterdata - Currency")
          description("Details of Currency")

          properties do
            code(:string, "Code of the Currency", required: true)
            name(:string, "Name of the Currency", required: true)
            sort(:integer, "Sort of the Currency", required: true)
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

    response(200, "OK", Schema.ref(:Currency))
    response(401, "Not Authorized")
    response(403, "Forbidden")
  end

  @doc false
  swagger_path :show do
    get("/api/v1/master_data/currencies/{id}")
    summary("Show Currency")
    description("Fetch a Currency by ID")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "Currency ID", required: true)
    end

    response(200, "OK", Schema.ref(:Currency))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  @doc false
  swagger_path :create do
    post("/api/v1/master_data/currencies/")
    summary("Create Currency")
    description("Create a new Currency.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Currency), "Currency attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Currency))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :update do
    put("/api/v1/master_data/currencies/{id}")
    summary("Update Currency")
    description("Update a Currency.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Currency), "Currency attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Currency))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/v1/master_data/currencies/{id}")
    summary("Delete Currency")
    description("Delete a Currency by ID.")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "Currency ID", required: true)
    end

    response(204, "No Content")
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end
end
