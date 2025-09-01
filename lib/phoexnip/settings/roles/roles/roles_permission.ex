defmodule Phoexnip.RolesPermission do
  @moduledoc """
  Represents a permission entry for a given role within Phoexnip.

  This schema stores the numeric permission identifier, its place within the sitemap,
  descriptive details, sequence order, and the association to a Roles.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Phoexnip.Roles

  @derive {Jason.Encoder, except: [:__meta__, :role]}
  schema "role_permissions" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    belongs_to :role, Roles
    field :permission, :integer
    field :sitemap_code, :string
    field :sitemap_name, :string
    field :sitemap_level, :integer
    field :sitemap_description, :string
    field :sitemap_parent, :string
    field :sitemap_url, :string
    field :sequence, :integer
  end

  @spec schema_casts() :: [atom()]
  defp schema_casts do
    # all schema fields except primary key and timestamps
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @typedoc """
  A RolesPermission struct.

  Fields:
  - `:id` - Primary key
  - `:role_id` - Foreign key to the associated Roles
  - `:permission` - Permission identifier
  - `:sitemap_code` - Code for sitemap grouping
  - `:sitemap_name` - Display name in the sitemap
  - `:sitemap_level` - Hierarchy level in the sitemap
  - `:sitemap_description` - Description for the sitemap entry
  - `:sitemap_parent` - Parent code for nesting
  - `:sitemap_url` - URL for the sitemap entry
  - `:sequence` - Ordering sequence within permissions
  - `:role` - The associated `Phoexnip.Roles` struct or not loaded
  """
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          role_id: integer() | nil,
          permission: integer() | nil,
          sitemap_code: String.t() | nil,
          sitemap_name: String.t() | nil,
          sitemap_level: integer() | nil,
          sitemap_description: String.t() | nil,
          sitemap_parent: String.t() | nil,
          sitemap_url: String.t() | nil,
          sequence: integer() | nil,
          role: Roles.t() | Ecto.Association.NotLoaded.t()
        }

  @doc """
  Builds a changeset for a RolesPermission based on the given `attrs`.

  Casts all relevant fields and validates presence of the core sitemap attributes:
  `:permission`, `:sitemap_code`, `:sitemap_name`, and `:sitemap_level`.
  """
  @spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(role_permission, attrs) do
    role_permission
    |> cast(attrs, schema_casts())
    |> validate_required([:permission, :sitemap_code, :sitemap_name, :sitemap_level])
  end
end
