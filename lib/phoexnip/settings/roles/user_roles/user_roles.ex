defmodule Phoexnip.UserRoles do
  @moduledoc """
  Represents the association of a User to a Roles within Phoexnip.

  This schema defines whether a user belongs in a given role, along with
  a role-specific name. It also tracks the underlying role and user associations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc """
  A struct representing a user's role assignment.

  Fields:
  - `:id` - Primary key
  - `:role_id` - Foreign key to the role
  - `:user_id` - Foreign key to the user
  - `:belongs_in_role` - Indicates if the user currently belongs in the role
  - `:role_name` - A custom name for the role assignment
  - `:role` - The associated `Phoexnip.Roles` struct or not loaded
  - `:user` - The associated `Phoexnip.Users.User` struct or not loaded
  """
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          role_id: integer() | nil,
          user_id: integer() | nil,
          belongs_in_role: boolean() | nil,
          role_name: String.t() | nil,
          role: Phoexnip.Roles.t() | Ecto.Association.NotLoaded.t(),
          user: Phoexnip.Users.User.t() | Ecto.Association.NotLoaded.t()
        }

  @derive {Jason.Encoder, except: [:__meta__, :role, :user]}
  schema "user_roles" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :belongs_in_role, :boolean, default: false
    field :role_name, :string
    belongs_to :role, Phoexnip.Roles
    belongs_to :user, Phoexnip.Users.User
  end

  @spec schema_casts() :: [atom()]
  defp schema_casts do
    # all schema fields except primary key and timestamps
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Builds a changeset based on the `attrs` provided.

  Validates the presence of `:role_id`, `:role_name`, and `:belongs_in_role`,
  and casts the `:user_id` as needed.
  """
  @spec changeset(
          t() | Ecto.Schema.t(),
          map()
        ) :: Ecto.Changeset.t()
  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, schema_casts())
    |> validate_required([:role_id, :role_name, :belongs_in_role])
  end
end
