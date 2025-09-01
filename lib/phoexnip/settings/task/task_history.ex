defmodule Phoexnip.Settings.TasksHistory do
  @moduledoc """
  Ecto schema and changeset functions for managing TasksHistory records.

  Each record has eight fields (task_id, task_entity, task_entity_id,
  task_entity_identifier, task_type, task_status, task_retry_date, message).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "A `%TasksHistory{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          task_id: integer() | nil,
          task_entity: String.t() | nil,
          task_entity_id: integer() | nil,
          task_entity_identifier: String.t() | nil,
          task_type: String.t() | nil,
          task_status: integer() | nil,
          task_retry_date: DateTime.t() | nil,
          message: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder, except: [:__meta__, :inserted_at, :updated_at]}
  schema "task_history" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :task_id, :integer
    # Products, BoM etc.
    field :task_entity, :string

    # Product.id for quick querying
    field :task_entity_id, :integer

    # Entity identifier for example Product.name
    field :task_entity_identifier, :string

    # CBD SYNC, the job will use this string to take the tasks it needs to do.
    field :task_type, :string

    # 0 - PENDING
    # 1 - WIP
    # 2 - SUCCESS
    field :task_status, :integer

    # if the task fails this date
    field :task_retry_date, :utc_datetime

    # Whatever message we receive
    field :message, :text

    timestamps(type: :utc_datetime)
  end

  @spec schema_fields() :: [atom()]
  defp schema_fields do
    # all fields except primary key and timestamps
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Builds a changeset for creating or updating a `%TasksHistory{}`.

  Casts all schema fields and enforces presence of all fields.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(tasks_history, attrs) when is_map(attrs) do
    tasks_history
    |> cast(attrs, schema_fields())
    |> validate_required([
      :task_id,
      :task_entity,
      :task_entity_id,
      :task_entity_identifier,
      :task_type,
      :task_status,
      :task_retry_date,
      :message
    ])
  end
end
