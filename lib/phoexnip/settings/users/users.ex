defmodule Phoexnip.Users.User do
  @moduledoc """
  The `User` schema and associated changeset functions for managing user accounts in Phoexnip.

  Provides functionality for registration, email and password updates, confirmation,
  credential encryption, and user-role associations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_email_regex ~r/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  @typedoc "An `%User{}` struct representing a user in the system."
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          email: String.t() | nil,
          password: String.t() | nil,
          password_confirmation: String.t() | nil,
          hashed_password: String.t() | nil,
          current_password: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          image_url: String.t() | nil,
          name: String.t() | nil,
          super_user: boolean() | nil,
          phone: String.t() | nil,
          group: String.t() | nil,
          credential: String.t() | nil,
          user_roles: [Phoexnip.UserRoles.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder,
           except: [
             :__meta__,
             :inserted_at,
             :updated_at,
             :hashed_password,
             :password,
             :current_password,
             :password_confirmation
           ]}
  schema "users" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :email, :citext
    field :password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :confirmed_at, :utc_datetime
    field :image_url, :text
    field :name, :text
    field :super_user, :boolean
    field :phone, :text
    field :group, :text
    field :credential, :text
    field :location, :string

    has_many :user_roles, Phoexnip.UserRoles, on_replace: :delete
    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for registering a new user.

  ## Options
    * `:hash_password` - whether to hash the password (default: `true`)
    * `:validate_email` - whether to enforce uniqueness of email (default: `true`)
  """
  @spec registration_changeset(t() | Ecto.Schema.t(), map(), keyword()) :: Ecto.Changeset.t()
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :name])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  @doc """
  Builds a changeset for updating the user's email.

  Adds an error if the email did not change.
  """
  @spec email_changeset(t() | Ecto.Schema.t(), map(), keyword()) :: Ecto.Changeset.t()
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = cs -> cs
      cs -> add_error(cs, :email, "did not change")
    end
  end

  @doc """
  Builds a changeset for updating the user's password.

  ## Options
    * `:hash_password` - whether to hash the new password (default: `true`)
  """
  @spec password_changeset(t() | Ecto.Schema.t(), map(), keyword()) :: Ecto.Changeset.t()
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Marks the user as confirmed by setting `confirmed_at` to the current UTC datetime.
  """
  @spec confirm_changeset(t() | Ecto.Schema.t()) :: Ecto.Changeset.t()
  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies a plaintext password against the stored hashed password.

  Returns `true` if the password matches, `false` otherwise.
  Runs `Bcrypt.no_user_verify/0` for missing users to mitigate timing attacks.
  """
  @spec valid_password?(t() | any(), String.t()) :: boolean()
  def valid_password?(%__MODULE__{hashed_password: hashed}, password)
      when is_binary(hashed) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed)
  end

  def valid_password?(_, _),
    do:
      (
        Bcrypt.no_user_verify()
        false
      )

  @doc """
  Validates the current password in a changeset, adding an error if invalid.
  """
  @spec validate_current_password(Ecto.Changeset.t(), String.t()) :: Ecto.Changeset.t()
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  @attrs_to_save_or_update [
    :name,
    :email,
    :password,
    :password_confirmation,
    :image_url,
    :phone,
    :group,
    :location,
    :credential
  ]

  @doc """
  Generic changeset for creating or updating users.

  Casts permitted attributes, enforces format and length constraints,
  lowercases email, encrypts password and credentials, and handles roles.
  """
  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(user, attrs) do
    user
    |> cast(attrs, @attrs_to_save_or_update)
    |> validate_length(:email, max: 255)
    |> validate_format(:email, @valid_email_regex)
    |> update_change(:email, &String.downcase/1)
    |> unique_constraint(:email)
    |> validate_required([:email, :name, :password, :password_confirmation])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_length(:password, min: 12, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/,
      message: "at least one digit or punctuation character"
    )
    |> maybe_hash_password(opts: true)
    |> maybe_encrypt_credentials()
    |> cast_assoc(:user_roles, with: &Phoexnip.UserRoles.changeset/2)
  end

  @doc """
  Generic changeset for updating existing users.

  Similar to `changeset/2` but does not require password fields.
  """
  @spec update_changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, @attrs_to_save_or_update)
    |> validate_length(:email, max: 255)
    |> validate_format(:email, @valid_email_regex)
    |> update_change(:email, &String.downcase/1)
    |> unique_constraint(:email)
    |> validate_required([:email, :name])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_length(:password, min: 12, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/,
      message: "at least one digit or punctuation character"
    )
    |> maybe_hash_password(opts: true)
    |> maybe_encrypt_credentials()
    |> cast_assoc(:user_roles, with: &Phoexnip.UserRoles.changeset/2)
  end

  @spec validate_email(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  @spec validate_password(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/,
      message: "at least one digit or punctuation character"
    )
    |> maybe_hash_password(opts)
  end

  @spec maybe_hash_password(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @spec maybe_validate_unique_email(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Phoexnip.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @spec maybe_encrypt_credentials(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp maybe_encrypt_credentials(changeset) do
    case get_change(changeset, :credential) do
      nil ->
        changeset

      plaintext ->
        put_change(changeset, :credential, Phoexnip.EncryptionUtils.gcm_encrypt(plaintext))
    end
  end
end
