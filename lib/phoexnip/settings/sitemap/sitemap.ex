defmodule Phoexnip.Sitemap do
  @moduledoc """
  Ecto schema and changeset functions for managing Sitemap records.

  Each record has seven fields (code, displayname, level, description, parent, url, sequence).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "A `%Sitemap{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          code: String.t() | nil,
          displayname: String.t() | nil,
          level: integer() | nil,
          description: String.t() | nil,
          parent: String.t() | nil,
          url: String.t() | nil,
          sequence: integer() | nil
        }

  @derive {Jason.Encoder, except: [:__meta__]}
  schema "sitemap" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :code, :string
    field :displayname, :string
    field :level, :integer
    field :description, :string
    field :parent, :string
    field :url, :string
    field :sequence, :integer
  end

  @spec schema_fields() :: [atom()]
  defp schema_fields do
    # all fields except primary key and timestamps
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Builds a changeset for creating or updating a `%Sitemap{}`.

  Casts all schema fields and enforces presence of all fields.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(sitemap, attrs) when is_map(attrs) do
    sitemap
    |> cast(attrs, schema_fields())
    |> validate_required([
      :code,
      :displayname,
      :level,
      :description,
      :parent,
      :url,
      :sequence
    ])
  end
end
