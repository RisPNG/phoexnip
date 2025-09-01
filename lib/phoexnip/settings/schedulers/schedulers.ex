defmodule Phoexnip.Settings.Schedulers do
  @moduledoc """
  Ecto schema and changeset functions for managing Schedulers records.

  Each record has three fields (name, cron_expression, status) and supports:

    * `changeset/2` – for creating or updating records (validates presence of all fields)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "A `%Schedulers{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          name: String.t() | nil,
          cron_expression: String.t() | nil,
          status: integer() | nil
        }

  @derive {Jason.Encoder, except: [:__meta__]}
  schema "schedulers" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :name, :string
    field :cron_expression, :string
    field :status, :integer
  end

  @spec schema_fields() :: [atom()]
  defp schema_fields do
    # all fields except the primary key
    __schema__(:fields) -- [:id]
  end

  @doc """
  Builds a changeset for creating or updating a `%Schedulers{}`.

  Casts all schema fields and ensures required fields are present.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(scheduler, attrs) when is_map(attrs) do
    scheduler
    |> cast(attrs, schema_fields())
    |> validate_required([:name, :cron_expression, :status])
  end
end
