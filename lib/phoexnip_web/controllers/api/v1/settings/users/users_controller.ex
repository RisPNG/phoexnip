defmodule PhoexnipWeb.UserController do
  @moduledoc """
  Handles HTTP API endpoints for user authentication and management in the Phoexnip application.

  This controller provides actions to:
    - `login/2`: Authenticate a user and issue an API key.
    - `refreshtoken/2`: Refresh the API key using a refresh token.
    - `index/2`: List users with pagination.
    - `show/2`: Retrieve a user by ID.
    - `create/2`: Create a new user.
    - `update/2`: Update an existing user.
    - `delete/2`: Delete a user.
    - `image/2`: Upload a profile image for a user.
    - `delete_image/2`: Remove a user's profile image.
    - `update_password/2`: Update a user's password.
    - `user_access/2`: Fetch permissions for a user.
    - `swagger_definitions/0`: Swagger schema definitions for user-related objects.
  """

  use PhoexnipWeb, :controller
  use PhoenixSwagger

  alias Phoexnip.Users.UserService
  alias Phoexnip.Users.User
  alias Phoexnip

  @doc """
  Authenticates a user by email and password, issues a new API key, and returns it.

  ## Parameters
    - conn: the connection struct.
    - params: map with "email" and "password" keys.

  ## Returns
    - Renders `:show_api_key` view with the API key on success.
    - Returns 401 Unauthorized if credentials are invalid.
    - Returns 422 Unprocessable Entity if input is invalid.
  """
  @spec login(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login(conn, %{"email" => email, "password" => password}) do
    if String.trim(email) == "" || String.trim(password) == "" do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{
        error: "Failed to login user invalid data provided"
      })
    end

    user = UserService.get_user_by_email_and_password(email, password)

    if user == nil do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Invalid username or password"})
      |> halt()
    else
      existing_key =
        Phoexnip.ServiceUtils.get_by(Phoexnip.Settings.ApiKey, %{given_to: user.email})

      new_key =
        if existing_key != nil do
          case Phoexnip.ServiceUtils.delete(existing_key) do
            {:ok, _} ->
              Phoexnip.AuditLogService.create_audit_log(
                "Apikey",
                existing_key.id,
                "delete",
                user,
                existing_key.given_to,
                %{},
                existing_key
              )

              case Phoexnip.Settings.ApiKey.generate_api_key(user.email) do
                {:ok, api_key} ->
                  Phoexnip.AuditLogService.create_audit_log(
                    "Apikey",
                    api_key.id,
                    "create",
                    user,
                    existing_key.given_to,
                    api_key,
                    %{}
                  )

                  api_key

                {:error, _} ->
                  nil
              end

            {:error, _} ->
              nil
          end
        else
          case Phoexnip.Settings.ApiKey.generate_api_key(user.email) do
            {:ok, api_key} ->
              Phoexnip.AuditLogService.create_audit_log(
                "Apikey",
                api_key.id,
                "create",
                user,
                api_key.given_to,
                api_key,
                %{}
              )

              api_key

            {:error, _} ->
              nil
          end
        end

      if new_key == nil do
        conn
        |> put_status(:badrequest)
        |> json(%{error: "badrequest: Something went wrong try again later!"})
        |> halt()
      else
        render(conn, :show_api_key, api_key: new_key)
      end
    end
  end

  @doc """
  Refreshes the API key using a valid refresh token.

  ## Parameters
    - conn: the connection struct.
    - params: map with "email" and "refreshToken" keys.

  ## Returns
    - Renders `:show_api_key` with the new API key on success.
    - Returns 403 Forbidden if the refresh token is invalid or expired.
    - Returns 422 Unprocessable Entity if input is invalid.
  """
  @spec refreshtoken(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def refreshtoken(conn, %{"email" => email, "refreshToken" => refreshToken}) do
    if String.trim(email) == "" || String.trim(refreshToken) == "" do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{
        error: "Invalid data provided"
      })
    end

    existing_key =
      Phoexnip.ServiceUtils.get_by(Phoexnip.Settings.ApiKey, %{
        refresh_key: refreshToken,
        given_to: email
      })

    if existing_key == nil ||
         NaiveDateTime.compare(NaiveDateTime.utc_now(), existing_key.refresh_until) == :gt do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Forbidden: Refresh key expired or email is invalid"})
      |> halt()
    else
      user = UserService.get_user_by_email(email)

      new_key =
        case Phoexnip.ServiceUtils.delete(existing_key) do
          {:ok, _} ->
            Phoexnip.AuditLogService.create_audit_log(
              "Apikey",
              existing_key.id,
              "delete",
              user,
              existing_key.given_to,
              %{},
              existing_key
            )

            case Phoexnip.Settings.ApiKey.generate_api_key(user.email) do
              {:ok, api_key} ->
                Phoexnip.AuditLogService.create_audit_log(
                  "Apikey",
                  api_key.id,
                  "refresh",
                  user,
                  api_key.given_to,
                  api_key,
                  %{}
                )

                api_key

              {:error, _} ->
                nil
            end

          {:error, _} ->
            nil
        end

      if new_key == nil do
        conn
        |> put_status(:badrequest)
        |> json(%{error: "badrequest: Something went wrong try again later!"})
        |> halt()
      else
        render(conn, :show_api_key, api_key: new_key)
      end
    end
  end

  @doc """
  Lists users with pagination.

  ## Parameters
    - conn: the connection struct.
    - params: map containing optional "page" and "per_page".

  ## Returns
    - Renders `:index` view with paginated list of users.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET1", 1) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    page = Map.get(params, "page", 1) |> Phoexnip.NumberUtils.validate_positive_integer(1)

    per_page =
      Map.get(params, "per_page", 20) |> Phoexnip.NumberUtils.validate_positive_integer(20)

    users = UserService.list(%{page: page, per_page: per_page})
    render(conn, :index, users: users)
  end

  @doc """
  Retrieves a user by ID.

  ## Parameters
    - conn: the connection struct.
    - params: map with "id" key.

  ## Returns
    - Renders `:show` view with the user on success.
    - Returns 404 Not Found if the user does not exist.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET1", 1) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case UserService.get_user_by(%{id: id}) do
      %User{} = user ->
        render(conn, :show, user: user)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  @doc """
  Creates a new user.

  ## Parameters
    - conn: the connection struct.
    - params: ignored; user attributes are from `conn.body_params`.

  ## Returns
    - Renders `:show` view with the created user on success.
    - Returns 422 Unprocessable Entity with error details on failure.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _) do
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET1", 2) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    user_params = conn.body_params["user"] || conn.body_params

    case UserService.create_user(user_params) do
      {:ok, %User{} = user} ->
        user = user |> Phoexnip.Repo.preload(:user_roles)

        Phoexnip.AuditLogService.create_audit_log(
          "User - API",
          user.id,
          "create",
          conn.assigns.current_user,
          user.email,
          user,
          %{}
        )

        conn
        |> put_status(:ok)
        |> render(:show, user: user)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Failed to create user",
          details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
        })
    end
  end

  @doc """
  Updates an existing user.

  ## Parameters
    - conn: the connection struct.
    - params: map with "id" key; user attributes are from `conn.body_params`.

  ## Returns
    - Renders `:show` view with the updated user on success.
    - Returns 404 Not Found if the user does not exist.
    - Returns 422 Unprocessable Entity with error details on failure.
  """
  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id}) do
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET1", 4) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    user_params = conn.body_params["user"] || conn.body_params

    case UserService.get_user_by(%{id: id}) do
      %User{} = user ->
        case UserService.update_user(user, user_params) do
          {:ok, %User{} = updated_user} ->
            Phoexnip.AuditLogService.create_audit_log(
              "User - API",
              updated_user.id,
              "update",
              conn.assigns.current_user,
              updated_user.email,
              updated_user,
              user
            )

            conn
            |> put_status(:ok)
            |> render(:show, user: updated_user)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to update user",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(changeset)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  @doc """
  Deletes a user by ID.

  ## Parameters
    - conn: the connection struct.
    - params: map with "id" key.

  ## Returns
    - Sends 204 No Content on success.
    - Returns 404 Not Found if user does not exist.
    - Returns 422 Unprocessable Entity with error details on failure.
  """
  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET1", 8) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case UserService.get_user_by(%{id: id}) do
      %User{} = user ->
        case UserService.delete_user(user) do
          {:ok, _} ->
            Phoexnip.AuditLogService.create_audit_log(
              "User - API",
              user.id,
              "delete",
              conn.assigns.current_user,
              user.email,
              %{},
              user
            )

            conn
            |> send_resp(:no_content, "")

          {:error, error} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to create user",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(error)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  @doc """
  Uploads a profile image for a user.

  ## Parameters
    - conn: the connection struct.
    - params: map with "id" key and "image" as a `%Plug.Upload{}`.

  ## Returns
    - Renders `:show` view with the updated user on success.
    - Returns 404 Not Found if user is not found.
    - Returns 422 Unprocessable Entity with error details on failure.
  """
  @spec image(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def image(conn, %{"id" => id, "image" => %Plug.Upload{} = upload}) do
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET1", 4) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case UserService.get_user_by(%{id: id}) do
      %User{} = user ->
        case Phoexnip.UploadUtils.save_upload(
               upload.path,
               user.image_url
             ) do
          {:ok, image_path} ->
            IO.inspect(image_path, label: "image_path")

            case UserService.update_user(user, %{image_url: image_path}) do
              {:ok, updated_user} ->
                Phoexnip.AuditLogService.create_audit_log(
                  "User - API",
                  updated_user.id,
                  "update",
                  conn.assigns.current_user,
                  updated_user.email,
                  updated_user,
                  user
                )

                conn
                |> put_status(:ok)
                |> render(:show, user: updated_user)

              {:error, error} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{
                  error: "Failed to update user",
                  details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(error)
                })
            end

          {:error, error} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to update user",
              details: "#{error}"
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  @doc """
  Deletes a user's profile image.

  ## Parameters
    - conn: the connection struct.
    - params: map with "id" key.

  ## Returns
    - Renders `:show` view with the updated user on success.
    - Returns 404 Not Found if user is not found.
    - Returns 422 Unprocessable Entity with error details on failure.
  """
  @spec delete_image(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete_image(conn, %{"id" => id}) do
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET1", 4) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    case UserService.get_user_by(%{id: id}) do
      %User{} = user ->
        case Phoexnip.UploadUtils.delete_upload(user.image_url) do
          {:ok, _} ->
            case UserService.update_user(user, %{image_url: ""}) do
              {:ok, updated_user} ->
                Phoexnip.AuditLogService.create_audit_log(
                  "User - API",
                  updated_user.id,
                  "update",
                  conn.assigns.current_user,
                  updated_user.email,
                  updated_user,
                  user
                )

                conn
                |> put_status(:ok)
                |> render(:show, user: updated_user)

              {:error, error} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{
                  error: "Failed to update user",
                  details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(error)
                })
            end

          {:error, message} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to delete image",
              details: message
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  @doc """
  Updates a user's password.

  ## Parameters
    - conn: the connection struct.
    - params: map with "id", "current_password", "password", and "password_confirmation".

  ## Returns
    - Sends 204 No Content on success.
    - Returns 404 Not Found if user is not found.
    - Returns 422 Unprocessable Entity with error details on failure.
  """
  @spec update_password(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_password(conn, %{
        "id" => id,
        "current_password" => current_password,
        "password" => password,
        "password_confirmation" => password_confirmation
      }) do
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET1", 4) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    end

    attr = %{
      "password" => password,
      "password_confirmation" => password_confirmation
    }

    case UserService.get_user_by(%{id: id}) do
      %User{} = user ->
        case UserService.update_user_password(user, current_password, attr) do
          {:ok, updated_user} ->
            Phoexnip.AuditLogService.create_audit_log(
              "User - API",
              updated_user.id,
              "update",
              conn.assigns.current_user,
              updated_user.email,
              updated_user,
              user
            )

            conn
            |> send_resp(:no_content, "")

          {:error, error} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to update user password",
              details: Phoexnip.ControllerUtils.convert_changeset_errors_to_json(error)
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  @doc """
  Fetches permissions for a user.

  ## Parameters
    - conn: the connection struct.
    - params: map with "id" key.

  ## Returns
    - JSON response with permissions data on success.
    - Returns 404 Not Found if user does not exist.
  """
  @spec user_access(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def user_access(conn, %{"id" => id}) do
    if Phoexnip.AuthenticationUtils.check_api_permissions(conn, "SET1", 1) == false do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized: Not enough permissions!"})
      |> halt()
    else
      if String.to_integer(id) == conn.assigns.current_user.id do
        conn
        |> put_status(:ok)
        |> json(%{data: conn.assigns.permissions})
      else
        case UserService.get_user_by(%{id: id}) do
          %User{} = user ->
            permission = Phoexnip.UserRolesService.fetch_user_permissions(user)

            conn
            |> put_status(:ok)
            |> json(%{data: permission})

          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "User not found"})
        end
      end
    end
  end

  @doc false
  swagger_path :login do
    post("/api/v1/users/login")
    summary("Login")
    description("Authenticates an API user and returns the API key")
    produces("application/json")
    consumes("application/json")

    parameters do
      body(:body, Schema.ref(:login_body), "Login attributes", required: true)
    end

    response(200, "OK", Schema.ref(:login_result))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :refreshtoken do
    post("/api/v1/users/refreshtoken")
    summary("Refreshes the API token.")
    description("Refreshes the API key if the refresh token is valid.")
    produces("application/json")
    consumes("application/json")

    parameters do
      body(
        :body,
        %{
          type: :object,
          properties: %{
            email: %{type: :string, description: "Login email"},
            refreshToken: %{type: :string, description: "The refresh token"}
          },
          required: [:refreshToken]
        },
        "Login attributes with refresh token",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:login_result))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :index do
    get("/api/v1/users")
    summary("List Users")
    description("Fetch a paginated list of users.")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      page(:query, :integer, "Page number", required: false, default: 1)
      per_page(:query, :integer, "Number of users per page", required: false, default: 20)
    end

    response(200, "OK", Schema.ref(:Users))
    response(401, "Not Authorized")
    response(403, "Forbidden")
  end

  @doc false
  swagger_path :show do
    get("/api/v1/users/{id}")
    summary("Show User")
    description("Fetch a user by their ID.")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
    end

    response(200, "OK", Schema.ref(:User))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  @doc false
  swagger_path :create do
    post("/api/v1/users")
    summary("Create User")
    description("Create a new user.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Create_User), "User attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Create_User))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :update do
    put("/api/v1/users/{id}")
    summary("Update User")
    description("Updates a user.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      body(:body, Schema.ref(:Update_User), "User attributes", required: true)
    end

    response(200, "OK", Schema.ref(:Update_User))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :update_password do
    put("/api/v1/users/{id}/updatepassword")
    summary("Update User")
    description("Updates a user password.")
    produces("application/json")
    consumes("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "User ID", required: true)

      body(:body, Schema.ref(:Update_User_Password), "Password update request body",
        required: true
      )
    end

    response(204, "No Content")
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/v1/users/{id}")
    summary("Delete User")
    description("Delete a user by their ID.")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
    end

    response(204, "No Content")
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  @doc false
  swagger_path :image do
    post("/api/v1/users/{id}/image")
    summary("Upload User Image")

    description(
      "Upload a profile image for the user. The file will be sent in `multipart/form-data` but processed as raw bytes."
    )

    consumes("multipart/form-data")
    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
      image(:formData, :file, "Profile image file", required: true)
    end

    response(200, "OK", Schema.ref(:User))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :delete_image do
    PhoenixSwagger.Path.delete("/api/v1/users/{id}/image")
    summary("Delete User Image")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
    end

    response(200, "OK", Schema.ref(:User))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  @doc false
  swagger_path :user_access do
    get("/api/v1/users/{id}/permissions")
    summary("Fetch User Permissions")

    description(
      "Fetch permissions for a user based on their role and the system sitemap. In short what the user can access in the system"
    )

    produces("application/json")
    security([%{"api_key" => []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
    end

    response(200, "OK", Schema.array(:Permission))
    response(401, "Not Authorized")
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  @doc """
  Returns the Swagger schema definitions for user-related objects.

  ## Returns
    - A map of Swagger schema definitions.
  """
  @spec swagger_definitions() :: map()
  def swagger_definitions do
    %{
      Create_User:
        swagger_schema do
          title("Create a user")
          description("Fields for creating a user.")

          properties do
            email(:string, "Email of the user", required: true)
            name(:string, "Full name of the user", required: true)
            phone(:string, "Phone number of the user", required: false)
            group(:string, "Group the user belongs to", required: false)
            password(:string, "User chosen password", required: true)

            password_confirmation(
              :string,
              "Confirmation of user chosen password",
              required: true
            )
          end
        end,
      Permission:
        swagger_schema do
          title("Users Permissions")

          description(
            "A permission object representing user permissions based on the sitemap. In short what the user can access in the system"
          )

          properties do
            sitemap_code(:string, "Sitemap code", required: true)
            sitemap_name(:string, "Sitemap name", required: true)
            sitemap_level(:integer, "Sitemap level", required: true)
            sitemap_parent(:string, "Parent sitemap code", required: false)
            sitemap_url(:string, "Sitemap URL", required: false)
            sequence(:integer, "Display order sequence", required: true)
            permission(:integer, "User permission level", required: true)

            children(
              Schema.array(:Permission),
              "Nested permissions for child sitemaps (this can only be for level 0)",
              required: false
            )
          end

          example(%{
            sitemap_code: "INV",
            sitemap_name: "Inventory",
            sitemap_level: 0,
            sitemap_parent: nil,
            sitemap_url: "",
            sequence: 20,
            permission: 16,
            children: [
              %{
                sitemap_code: "INV1",
                sitemap_name: "Product Management",
                sitemap_level: 1,
                sitemap_parent: "INV",
                sitemap_url: "product",
                sequence: 30,
                permission: 16
              }
            ]
          })
        end,
      Update_User:
        swagger_schema do
          title("Update a user")
          description("Fields for updating a user.")

          properties do
            name(:string, "Full name of the user", required: false)
            phone(:string, "Phone number of the user", required: false)
            group(:string, "Group the user belongs to", required: false)
          end
        end,
      Update_User_Password:
        swagger_schema do
          title("Update user password")
          description("Update a user's password")

          properties do
            current_password(:string, "User's current password", required: true)
            password(:string, "User's newly selected password", required: true)
            password_confirmation(:string, "User's password confirmation", required: true)
          end
        end,
      login_body:
        swagger_schema do
          title("Login body")
          description("Authenticate to the API")

          properties do
            password(:string, "User password", required: true)
            email(:string, "User email", required: true)
          end
        end,
      login_result:
        swagger_schema do
          title("Login result")
          description("Information about the API key and validation")

          properties do
            given_to(:string, "User email", required: true)
            key(:string, "API Key", required: true)
            refresh_key(:string, "Refresh Key", required: true)
            valid_until(:string, "API key valid till in UTC", format: :date_time, required: true)

            refresh_until(:string, "Refresh key valid till in UTC",
              format: :date_time,
              required: true
            )
          end
        end,
      User:
        swagger_schema do
          title("User")
          description("A registered user of the system.")

          properties do
            id(:integer, "User ID")
            email(:string, "Email of the user", required: false)
            name(:string, "Full name of the user", required: false)
            image_url(:string, "Profile image URL of the user", required: false)
            phone(:string, "Phone number of the user", required: false)
            group(:string, "Group the user belongs to", required: false)

            inserted_at(:string, "Timestamp when the user was created",
              format: "date-time",
              required: false
            )

            updated_at(:string, "Timestamp when the user was last updated",
              format: "date-time",
              required: false
            )
          end
        end,
      Users:
        swagger_schema do
          title("Users")
          description("A paginated list of users.")

          properties do
            data(Schema.array(:User), "List of users")
          end
        end
    }
  end
end
