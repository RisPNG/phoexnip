defmodule PhoexnipWeb.RolesController do
  @moduledoc """
  Handles HTTP API endpoints for Roles in the Phoexnip application.

  This controller provides actions to:
    - list roles (`index/2`)
    - show a role (`show/2`)
    - create a role (`create/2`)
    - update a role (`update/2`)
    - delete a role (`delete/2`)
    - Swagger schema definitions (`swagger_definitions/0`)

  All actions enforce API permission checks and return JSON responses.
  """

  use PhoexnipWeb, :controller
  use PhoenixSwagger

  alias Phoexnip.Roles
  alias Phoexnip.ServiceUtils
  alias Phoexnip.SearchUtils
  import Ecto.Query, warn: false

  @doc """
  Renders a paginated list of roles.

  ## Parameters

    - conn: the connection struct.
    - params: map of request parameters, including optional "page" and "per_page".

  ## Returns

    - Updated connection with JSON response containing the list of roles.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET2", 1) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    # Extract page and per_page from params with default values
    page = Map.get(params, "page", 1) |> Phoexnip.NumberUtils.validate_positive_integer(1)

    per_page =
      Map.get(params, "per_page", 20) |> Phoexnip.NumberUtils.validate_positive_integer(20)

    %{entries: roles} =
      SearchUtils.search(
        pagination: %{page: page, per_page: per_page},
        module: Phoexnip.Roles
      )

    render(conn, :index, roles: roles)
  end

  @doc """
  Retrieves and renders a role by ID.

  ## Parameters

    - conn: the connection struct.
    - params: map with string "id" key identifying the role.

  ## Returns

    - Updated connection with JSON response of the role or error status.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET2", 1) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case ServiceUtils.get_with_preload(Phoexnip.Roles, id,
           role_permissions: from(rp in Phoexnip.RolesPermission, order_by: rp.id)
         ) do
      %Roles{} = role ->
        render(conn, :show, role: role)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Roles not found"})
    end
  end

  @doc """
  Creates a new role from the request body.

  ## Parameters

    - conn: the connection struct.
    - params: ignored; role attributes are read from conn.body_params.

  ## Returns

    - Updated connection with JSON response of the created role or error details.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET2", 2) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    # Extracting the user parameters from the body_params of the connection
    role_params = conn.body_params["role"] || conn.body_params

    case ServiceUtils.create(Phoexnip.Roles, role_params) do
      {:ok, %Roles{} = role} ->
        Phoexnip.AuditLogService.create_audit_log(
          # Entity type
          "Roles - API",
          # Entity ID
          role.id,
          # Action type
          "create",
          # User who performed the action
          conn.assigns.current_user,
          role.name,
          # New data (changes)
          role,
          # Previous data (empty since it's a new record)
          %{}
        )

        conn
        |> put_status(:ok)
        |> render(:show, role: role)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Failed to create role",
          details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
        })
    end
  end

  @doc """
  Updates an existing role by ID.

  ## Parameters

    - conn: the connection struct.
    - params: map with string "id" key and role attributes in conn.body_params.

  ## Returns

    - Updated connection with JSON response of the updated role or error details.
  """
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id}) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET2", 4) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    # Extracting the user parameters from the body_params of the connection
    role_params = conn.body_params["role"] || conn.body_params

    case ServiceUtils.get(Phoexnip.Roles, id) do
      %Roles{} = role ->
        case ServiceUtils.update(role, role_params) do
          {:ok, %Roles{} = updated_role} ->
            Phoexnip.AuditLogService.create_audit_log(
              # Entity type
              "Roles - API",
              # Entity ID
              updated_role.id,
              # Action type
              "update",
              # User who performed the action
              conn.assigns.current_user,
              updated_role.name,
              # New data (changes)
              updated_role,
              # Previous data (empty since it's a new record)
              role
            )

            conn
            |> put_status(:ok)
            |> render(:show, role: updated_role)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to update role",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Roles not found"})
    end
  end

  @doc """
  Deletes a role by ID.

  ## Parameters

    - conn: the connection struct.
    - params: map with string "id" key.

  ## Returns

    - Updated connection with no content response or error details.
  """
  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    # permission checking like we do on the pages.
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET2", 8) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case ServiceUtils.get(Phoexnip.Roles, id) do
      %Roles{} = role ->
        case ServiceUtils.delete(role) do
          {:ok, _} ->
            Phoexnip.AuditLogService.create_audit_log(
              # Entity type
              "Roles - API",
              # Entity ID
              role.id,
              # Action type
              "delete",
              # User who performed the action
              conn.assigns.current_user,
              role.name,
              # New data (changes)
              %{},
              # Previous data (empty since it's a new record)
              role
            )

            conn
            |> send_resp(:no_content, "")

          {:error, error} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to delete role",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(error)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Roles not found"})
    end
  end

  @doc """
  Returns the Swagger schema definitions for Roles and related objects.

  ## Returns

    - A map of Swagger schema definitions.
  """
  @spec swagger_definitions() :: map()
  def swagger_definitions do
    %{
      Roles:
        swagger_schema do
          title("Roles")
          description("A role that can have multiple permissions.")

          properties do
            name(:string, "Name of the role", required: true)
            description(:string, "Description of the role", required: false)
          end
        end,
      Roles_And_Permissions:
        swagger_schema do
          title("Roles with permissions")
          description("A role that can have multiple permissions.")

          properties do
            name(:string, "Name of the role", required: true)
            description(:string, "Description of the role", required: false)

            role_permissions(array(:RolesPermission), "List of role permissions", required: false)
          end
        end,
      RolesPermission:
        swagger_schema do
          title("Roles Permission")
          description("Permission details for a specific role.")

          properties do
            permission(:integer, "Permission value", required: true)
            sitemap_code(:string, "Code representing the sitemap", required: true)
            sitemap_name(:string, "Name of the sitemap", required: true)
            sitemap_level(:integer, "Level of the sitemap", required: true)
            sitemap_parent(:string, "Parent identifier for the permission", required: false)
            sitemap_url(:string, "URL for the sitemap", required: false)
            sequence(:integer, "Sequence of the sitemap", required: false)
            role_id(:integer, "ID of the associated role", required: true)
          end
        end,
      Update_RolesPermission:
        swagger_schema do
          title("Roles Permission")
          description("Permission details for a specific role.")

          properties do
            id(:integer, "ID of the Permission", required: true)
            permission(:integer, "Permission value", required: true)
            sitemap_code(:string, "Code representing the sitemap", required: true)
            sitemap_name(:string, "Name of the sitemap", required: true)
            sitemap_level(:integer, "Level of the sitemap", required: true)
            sitemap_parent(:string, "Parent identifier for the permission", required: false)
            sitemap_url(:string, "URL for the sitemap", required: false)
            sequence(:integer, "Sequence of the sitemap", required: false)
            role_id(:integer, "ID of the associated role", required: true)
          end
        end
    }
  end

  @doc false
  swagger_path :index do
    get("/api/v1/roles")
    summary("List of roles")
    description("Fetch a paginated list of roles.")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      page(:query, :integer, "Page number", required: false, default: 1)
      per_page(:query, :integer, "Number of users per page", required: false, default: 20)
    end

    response(200, "OK", Schema.ref(:Roles))
    response(401, "Not Authorized")
    response(403, "Forbidden")
  end

  @doc false
  swagger_path :show do
    get("/api/v1/roles/{id}")
    summary("Show Roles")
    description("Fetch a Roles by their ID and returns its permissions.")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "Roles ID", required: true)
    end

    response(200, "OK", Schema.ref(:Roles_And_Permissions))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  @doc false
  swagger_path :create do
    post("/api/v1/roles")
    summary("Create Roles")
    description("Create a new role.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Roles_And_Permissions), "Roles attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Roles_And_Permissions))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :update do
    put("/api/v1/roles/{id}")
    summary("Update Roles")
    description("Updates a Roles.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Roles_And_Permissions), "Roles attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Roles_And_Permissions))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/v1/roles/{id}")
    summary("Delete Roles")
    description("Delete a role by their ID.")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "Roles ID", required: true)
    end

    response(204, "No Content")
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end
end
