defmodule Phoexnip.Users.UserService do
  @moduledoc """
  The Users context: manages user accounts, authentication, email updates,
  password resets, and session tokens.

  Provides functions to:
    * Retrieve and authenticate users (`get_user_by_email/1`, `get_user_by_email_and_password/2`, `get!/1`)
    * Register, update, and delete users (`register_user/1`, `create_user/1`, `update_user/2`, `delete_user/1`)
    * Change and apply user email updates (`change_user_email/2`, `apply_user_email/3`, `update_user_email/2`)
    * Change, update, and reset user passwords (`change_user_password/2`, `update_user_password/3`, `reset_user_password/2`)
    * Generate, verify, and delete session tokens (`generate_user_session_token/1`, `get_user_by_session_token/1`, `delete_user_session_token/1`)
    * Deliver email notifications via `Phoexnip.Users.UserNotifier` for confirmations and password resets
    * Confirm users (`deliver_user_confirmation_instructions/2`, `confirm_user/1`)
    * List and paginate users (`list/1`, `list_users_dropdown/0`, `list_all_users_dropdown/0`)
    * Retrieve and decrypt credentials (`get_credentials/1`, `decrypt_credentials/1`, `update_nike_acs_credentails/2`)
  """

  @dialyzer {:nowarn_function,
             user_email_multi: 3,
             update_user_password: 3,
             confirm_user_multi: 1,
             reset_user_password: 2}

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Users.{User, UserToken, UserNotifier}

  @doc """
  Gets a user by email address.

  ## Examples
      iex> get_user_by_email("foo@example.com")
      %User{}
      iex> get_user_by_email("unknown@example.com")
      nil
  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and verifies the password.

  Returns the `User` if credentials are valid, or `nil` otherwise.

  ## Examples
      iex> get_user_by_email_and_password("foo@example.com", "secret")
      %User{}
      iex> get_user_by_email_and_password("foo@example.com", "wrong")
      nil
  """
  @spec get_user_by_email_and_password(String.t(), String.t()) :: User.t() | nil
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Retrieves a single user by ID, raising if not found.
  Preloads `:user_roles`.

  ## Examples
      iex> get!(123)
      %User{}
      iex> get!(456)
      ** (Ecto.NoResultsError)
  """
  @spec get!(integer() | String.t()) :: User.t()
  def get!(id), do: Repo.get!(User, id) |> Repo.preload(:user_roles)

  @doc """
  Registers a new user with the given attributes.

  ## Examples
      iex> register_user(%{email: "foo@bar.com", password: "secret"})
      {:ok, %User{}}
      iex> register_user(%{email: "bad", password: "short"})
      {:error, %Ecto.Changeset{}}
  """
  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a changeset for user registration without applying it.
  Use for form rendering.
  """
  @spec change_user_registration(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  @doc """
  Returns a changeset for updating a user's email.
  """
  @spec change_user_email(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Validates current password and applies an email change without persisting.

  ## Examples
      iex> apply_user_email(user, "password", %{email: "new@ex.com"})
      {:ok, %User{email: "new@ex.com"}}
      iex> apply_user_email(user, "wrong", %{email: "new@ex.com"})
      {:error, %Ecto.Changeset{}}
  """
  @spec apply_user_email(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user's email using a confirmation token.

  Returns `:ok` on success, or `:error` if token is invalid.
  """
  @spec update_user_email(User.t(), String.t()) :: :ok | :error
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc """
  Returns a changeset for changing the user's password.
  """
  @spec change_user_password(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user's password after validating the current password.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  @spec update_user_password(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Generates a session token and stores it in the database.

  ## Examples
      iex> token = generate_user_session_token(user)
  """
  @spec generate_user_session_token(User.t()) :: String.t()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Retrieves the user associated with the given session token.

  Returns the `User` or `nil`.
  """
  @spec get_user_by_session_token(String.t()) :: User.t() | nil
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the session token from the database.

  Returns `:ok` on success.
  """
  @spec delete_user_session_token(String.t()) :: :ok
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  @doc """
  Confirms a user account by token and marks it as confirmed.

  Returns `{:ok, user}` or `:error`.
  """
  @spec confirm_user(String.t()) :: {:ok, User.t()} | :error
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  @doc """
  Sends reset password instructions to the user via email.

  Returns `{:ok, info}`.
  """
  @spec deliver_user_reset_password_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, map()}
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Retrieves a user by a valid reset password token, or `nil` if invalid.
  """
  @spec get_user_by_reset_password_token(String.t()) :: User.t() | nil
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets a user's password and deletes all their tokens.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  @spec reset_user_password(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Returns a paginated list of non-super users.

  ## Examples
      iex> list(%{page: 1, per_page: 10})
      [%User{}, ...]
  """
  @spec list(%{page: integer(), per_page: integer()}) :: [User.t()]
  def list(%{page: page, per_page: per_page}) do
    offset = (page - 1) * per_page

    Repo.all(
      from(c in User,
        order_by: [asc: c.id],
        where: c.super_user == false,
        limit: ^per_page,
        offset: ^offset
      )
    )
    |> Repo.preload(:user_roles)
  end

  @doc """
  Returns a list of non-super users for dropdowns.
  """
  @spec list_users_dropdown() :: [User.t()]
  def list_users_dropdown do
    Repo.all(
      from(c in User,
        where: c.super_user == false,
        order_by: [asc: c.id]
      )
    )
  end

  @doc """
  Returns a list of all users for dropdowns.
  """
  @spec list_all_users_dropdown() :: [User.t()]
  def list_all_users_dropdown do
    Repo.all(from(c in User, order_by: [asc: c.id]))
  end

  @doc """
  Retrieves a user by given attributes and preloads roles.
  """
  @spec get_user_by(keyword() | map()) :: User.t() | nil
  def get_user_by(args), do: Repo.get_by(User, args) |> Repo.preload(:user_roles)

  @doc """
  Returns a changeset for updating user attributes.
  """
  @spec change(User.t(), map()) :: Ecto.Changeset.t()
  def change(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Creates a new user.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes an existing user.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  @spec delete_user(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Updates a user's attributes.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for updating a user without saving.
  """
  @spec change_update(User.t(), map()) :: Ecto.Changeset.t()
  def change_update(%User{} = user, attrs) do
    User.update_changeset(user, attrs)
  end

  @doc """
  Retrieves and decrypts stored credential for the given username.

  Returns a `%User{}` with decrypted credential or `nil` if not found.
  """
  @spec get_credentials(String.t()) :: User.t() | nil
  def get_credentials(username) do
    case get_user_by(%{name: username}) do
      %User{} = user -> decrypt_credentials(user)
      _ -> nil
    end
  end

  @doc """
  Decrypts the `:credential` field in the user struct.
  """
  @spec decrypt_credentials(User.t()) :: User.t()
  def decrypt_credentials(%User{credential: enc} = struct) when is_binary(enc) do
    case Phoexnip.EncryptionUtils.gcm_decrypt(enc) do
      {:ok, dec} -> %{struct | credential: dec}
      _ -> struct
    end
  end

  def decrypt_credentials(struct), do: struct

  @doc """
  Updates Nike ACS credentials for the given username.

  Returns the result of `update_user/2`.
  """
  @spec update_nike_acs_credentails(String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_nike_acs_credentails(username, map) do
    user = get_user_by(%{name: username})
    update_user(user, map)
  end
end
