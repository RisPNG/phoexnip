defmodule PhoexnipWeb.UserSessionController do
  use PhoexnipWeb, :controller

  alias Phoexnip.Users.UserService
  alias PhoexnipWeb.UserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/account/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = UserService.get_user_by_email_and_password(email, password) do
      user = user |> Phoexnip.Repo.preload(:user_roles)
      # Create the audit log after customer creation
      Phoexnip.AuditLogService.create_audit_log(
        # Entity type
        "Log In",
        # Entity ID
        -2,
        # Action type
        "success",
        # User who performed the action
        user,
        # Unique identifier that isnt the ID incase of deletion.
        user.email,
        # New data (changes)
        user,
        # Previous data (empty since it's a new record)
        %{}
        # Metadata (example: user's IP)
      )

      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # Create the audit log after customer creation
      case Phoexnip.AuditLogService.create_audit_log(
             # Entity type
             "Log In",
             # Entity ID
             -1,
             # Action type
             "fail",
             # User who performed the action
             %{id: -1, name: "Mystery"},
             "",
             # New data (changes)
             user_params,
             # Previous data (empty since it's a new record)
             %{}
             # Metadata (example: user's IP)
           ) do
        {:ok, _auditlog} ->
          # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
          conn
          |> put_flash(:error, "Invalid email or password")
          |> put_flash(:email, String.slice(email, 0, 160))
          |> redirect(to: ~p"/log_in")

        {:error, _changeset} ->
          # Even if audit log fails, continue with the user-facing flow.
          conn
          |> put_flash(:error, "Invalid email or password")
          |> put_flash(:email, String.slice(email, 0, 160))
          |> redirect(to: ~p"/log_in")
      end
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
