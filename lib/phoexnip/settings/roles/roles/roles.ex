defmodule Phoexnip.Roles do
  @moduledoc """
  Represents a role within Phoexnip.

  This schema stores the role's name, description, timestamps,
  and associated role_permissions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc """
  A Roles struct.

  Fields:
  - `:id` - Primary key
  - `:name` - The name of the role
  - `:description` - Detailed description of the role
  - `:inserted_at` - When the record was created
  - `:updated_at` - When the record was last updated
  - `:role_permissions` - Associated permissions for this role
  """
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil,
          role_permissions: [Phoexnip.RolesPermission.t()] | Ecto.Association.NotLoaded.t()
        }

  @derive {Jason.Encoder, except: [:__meta__]}
  schema "roles" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :name, :string
    field :description, :string
    timestamps(type: :utc_datetime)

    has_many :role_permissions, Phoexnip.RolesPermission,
      foreign_key: :role_id,
      on_replace: :delete
  end

  @spec schema_casts() :: [atom()]
  defp schema_casts do
    # all schema fields except primary key and timestamps
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Builds a changeset for a Roles based on the given `attrs`.

  Casts the `:name`, `:description`, `:inserted_at`, and `:updated_at` fields,
  validates the presence of `:name`, enforces uniqueness on `:name`,
  and casts associated `:role_permissions`.
  """
  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(role, attrs) do
    role
    |> cast(attrs, schema_casts())
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> cast_assoc(:role_permissions)
  end
end
