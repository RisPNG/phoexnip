defmodule Phoexnip.AuditLogs do
  @moduledoc """
  Represents an audit log entry.
  Tracks create/update/delete operations on various entities,
  including what changed, who performed the action, and when.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "An `%AuditLogs{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          entity_type: String.t() | nil,
          entity_id: integer() | nil,
          entity_unique_identifier: String.t() | nil,
          action: String.t() | nil,
          changes: String.t() | nil,
          previous_data: String.t() | nil,
          metadata: map() | nil,
          user_id: integer() | nil,
          user_name: String.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  schema "audit_logs" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    # Type of entity (e.g., 'Supplier', 'Order')
    field :entity_type, :string
    # ID of the entity being modified
    field :entity_id, :integer

    # A unique identifier that is not the ID for when people delete shit and we still want to find back the old info.
    field :entity_unique_identifier, :string
    # Action: 'create', 'update', 'delete'
    field :action, :string
    # Changes made during updates (new values)
    field :changes, :text
    # Data before the change (old values), useful for updates and deletes
    field :previous_data, :text
    # Any additional metadata (IP, session, etc.)
    field :metadata, :text
    # User ID who performed the action
    field :user_id, :integer
    # Name of the user who performed the action
    field :user_name, :string
    # Timestamp when the action occurred
    field :inserted_at, :utc_datetime
  end

  @spec schema_casts() :: [atom()]
  defp schema_casts do
    # allow casting of all fields except primary key and updated_at
    # inserted_at is provided explicitly by the service layer
    __schema__(:fields) -- [:id, :updated_at]
  end

  @doc """
  Builds and validates a changeset for an audit log entry.

  ## Parameters

    * `audit_log` — an `%AuditLogs{}` struct or `%Ecto.Changeset{}`.
    * `attrs` — a map of attributes to cast onto the struct.

  ## Validation

    * Requires `:entity_type`, `:entity_id`, `:action`, and `:inserted_at`.
  """
  @spec changeset(audit_log :: t() | Ecto.Changeset.t(), attrs :: map()) :: Ecto.Changeset.t()
  def changeset(audit_log, attrs) when is_map(attrs) do
    audit_log
    |> cast(attrs, schema_casts())
    # Do not require user_id
    |> validate_required([:entity_type, :entity_id, :action, :inserted_at])
  end
end
