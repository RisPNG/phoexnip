defmodule Phoexnip.Settings.ApiKey do
  @moduledoc """
  Ecto schema and changeset functions for managing ApiKey records.

  Each record holds a generated API key, its owner, and validity timestamps.
  Provides:

    * `changeset/2` – for creating or updating `%ApiKey{}` records (casts fields, validates presence, enforces unique `:key`)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "An `%ApiKey{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          given_to: String.t() | nil,
          key: String.t() | nil,
          valid_until: DateTime.t() | nil,
          refresh_key: String.t() | nil,
          refresh_until: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder, except: [:__meta__, :inserted_at, :updated_at]}
  schema "api_key" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :given_to, :string
    field :key, :string
    field :valid_until, :utc_datetime
    field :refresh_key, :string
    field :refresh_until, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec schema_casts() :: [atom()]
  defp schema_casts do
    # all schema fields except primary key and timestamps
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Builds a changeset for **creating or updating** an `%ApiKey{}`.

  Casts all schema fields, ensures required fields are present, and checks uniqueness of `:key`.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(api_key, attrs) when is_map(attrs) do
    api_key
    |> cast(attrs, schema_casts())
    |> validate_required([:key, :given_to, :valid_until, :refresh_key, :refresh_until])
    |> unique_constraint(:key)
  end
end
