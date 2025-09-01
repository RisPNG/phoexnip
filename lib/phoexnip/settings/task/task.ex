defmodule Phoexnip.Settings.Tasks do
  @moduledoc """
  Ecto schema and changeset functions for managing ACS sync tasks.

  Each `%Tasks{}` represents a work item for Nike ACS integration, such as pushing
  costing data or attachments. Provides:

    * `changeset/2` – for creating or updating tasks with validated fields
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "A `%Tasks{}` struct representing a Nike ACS sync task"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          task_entity: String.t() | nil,
          task_entity_id: integer() | nil,
          task_entity_identifier: String.t() | nil,
          task_type: String.t() | nil,
          task_status: integer() | nil,
          task_retry_date: DateTime.t() | nil,
          task_initiator: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder, except: [:__meta__, :inserted_at, :updated_at]}
  schema "task" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
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

    # the user name who created this task.
    field :task_initiator, :string

    timestamps(type: :utc_datetime)
  end

  @spec schema_casts() :: [atom()]
  defp schema_casts do
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Builds a changeset for creating or updating a `%Tasks{}` record.

  Casts all schema fields, without requiring any specific field,
  but ensures the provided `attrs` map is applied cleanly.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(tasks, attrs) when is_map(attrs) do
    tasks
    |> cast(attrs, schema_casts())
  end
end
