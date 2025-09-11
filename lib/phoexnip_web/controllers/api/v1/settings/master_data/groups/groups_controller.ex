defmodule PhoexnipWeb.MasterDataGroupsController do
  @moduledoc """
  Handles HTTP API endpoints for Groups master data in the Phoexnip application.

  This controller provides actions to:
    - list groups (`index/2`)
    - show a group (`show/2`)
    - create a new group (`create/2`)
    - update an existing group (`update/2`)
    - delete a group (`delete/2`)
    - expose Swagger schema definitions (`swagger_definitions/0`)

  All actions enforce Level Two API permission checks and render JSON responses.
  """

  use PhoexnipWeb, :controller
  use PhoenixSwagger

  alias Phoexnip.Masterdata.Groups
  alias Phoexnip.Masterdata.GroupsService

  @doc """
  Lists all groups.

  ## Parameters

    - conn: the connection struct.
    - _params: request parameters (ignored).

  ## Returns

    - Connection with status 200 and JSON body:
      ```elixir
      %{masterdatas: [%Groups{}, …]}
      ```
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3N",
         1
       ) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    masterdatas = GroupsService.list()
    render(conn, :index, masterdatas: masterdatas)
  end

  @doc """
  Retrieves a single group by its ID.

  ## Parameters

    - conn: the connection struct.
    - params: map with `"id"` key as string or integer.

  ## Returns

    - Status 200 and JSON body `%{masterdata: %Groups{}}` if found.
    - Status 404 and `%{error: "Not found"}` if no group exists with the given ID.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3N",
         1
       ) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case GroupsService.get(id) do
      %Groups{} = group ->
        render(conn, :show, masterdata: group)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Not found"})
    end
  end

  @doc """
  Creates a new group.

  ## Parameters

    - conn: the connection struct.
    - _params: ignored; attributes are fetched from `conn.body_params["groups"]` or directly from `conn.body_params`.

  ## Returns

    - Status 200 and `%{masterdata: %Groups{}}` on success.
    - Status 422 and error details on validation failure.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _) do
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3N",
         2
       ) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    params = conn.body_params["groups"] || conn.body_params

    case GroupsService.create(params) do
      {:ok, %Groups{} = group} ->
        Phoexnip.AuditLogService.create_audit_log(
          "Groups - API",
          group.id,
          "create",
          conn.assigns.current_user,
          group.code,
          group,
          %{}
        )

        conn
        |> put_status(:ok)
        |> render(:show, masterdata: group)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Failed to create Groups",
          details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
        })
    end
  end

  @doc """
  Updates an existing group by ID.

  ## Parameters

    - conn: the connection struct.
    - params: map containing `"id"` and update attributes in `conn.body_params`.

  ## Returns

    - Status 200 and `%{masterdata: %Groups{}}` on success.
    - Status 404 if the group is not found.
    - Status 422 and error details if update fails.
  """
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id}) do
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3N",
         4
       ) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case GroupsService.get(id) do
      %Groups{} = group ->
        case GroupsService.update(group, conn.body_params) do
          {:ok, %Groups{} = updated_group} ->
            IO.inspect(updated_group, label: "updated_masterdata")

            Phoexnip.AuditLogService.create_audit_log(
              "Groups - API",
              updated_group.id,
              "update",
              conn.assigns.current_user,
              updated_group.code,
              updated_group,
              group
            )

            conn
            |> put_status(:ok)
            |> render(:show, masterdata: updated_group)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to update Groups",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Groups not found"})
    end
  end

  @doc """
  Deletes a group by ID.

  ## Parameters

    - conn: the connection struct.
    - params: map with `"id"` key.

  ## Returns

    - Status 204 on successful deletion.
    - Status 404 if not found.
    - Status 422 with error details if deletion fails.
  """
  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    if Phoexnip.AuthenticationUtils.check_api_permissions_level_two(
         conn.assigns.current_user,
         "SET3N",
         8
       ) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case GroupsService.get(id) do
      %Groups{} = group ->
        case GroupsService.delete(group) do
          {:ok, _} ->
            Phoexnip.AuditLogService.create_audit_log(
              "Groups - API",
              group.id,
              "delete",
              conn.assigns.current_user,
              group.code,
              %{},
              group
            )

            conn
            |> send_resp(:no_content, "")

          {:error, error} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to delete Country",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(error)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Groups not found"})
    end
  end

  @doc """
  Returns Swagger schema definitions for Groups.

  ## Returns

    - A map of named Swagger schema definitions.
  """
  @spec swagger_definitions() :: map()
  def swagger_definitions do
    %{
      Country:
        swagger_schema do
          title("Masterdata - Groups")
          description("Details of Groups")

          properties do
            code(:string, "Code of the Groups", required: true)
            name(:string, "Name of the Groups", required: true)
            sort(:integer, "Sort of the Groups", required: true)
          end
        end
    }
  end

  @doc false
  swagger_path :index do
    get("/api/v1/master_data/groups")
    summary("List of Groups")
    description("Fetch a paginated list of Groups.")
    produces("application/json")
    security([%{"api_key" => []}])

    response(200, "OK", Schema.ref(:Country))
    response(401, "Not Authorized")
    response(403, "Forbidden")
  end

  @doc false
  swagger_path :show do
    get("/api/v1/master_data/groups/{id}")
    summary("Show Groups")
    description("Fetch a Country by their ID")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "Groups ID", required: true)
    end

    response(200, "OK", Schema.ref(:Country))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  @doc false
  swagger_path :create do
    post("/api/v1/master_data/groups/")
    summary("Create Groups")
    description("Create a new Country.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Country), "Groups attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Country))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :update do
    put("/api/v1/master_data/groups/{id}")
    summary("Update Groups")
    description("Updates a Country.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Country), "Groups attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Country))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/v1/master_data/groups/{id}")
    summary("Delete Groups")
    description("Delete a Country by their ID.")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "Groups ID", required: true)
    end

    response(204, "No Content")
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end
end
