defmodule Phoexnip.AuditLogService do
  @moduledoc """
  Provides functions to list, fetch, and create audit log records.
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.AuditLogs

  @doc """
  Returns all audit log records.

  ## Examples

      iex> Phoexnip.AuditLogService.list()
      [%Phoexnip.AuditLogs{}, ...]
  """
  @spec list() :: [AuditLogs.t()]
  def list do
    Repo.all(AuditLogs)
  end

  @doc """
  Fetches a single audit log by its primary key. Raises if not found.

  ## Parameters

    * `id` — the primary key (integer or binary).

  ## Examples

      iex> Phoexnip.AuditLogService.get!(1)
      %Phoexnip.AuditLogs{id: 1, ...}

      iex> Phoexnip.AuditLogService.get!(9999)
      ** (Ecto.NoResultsError)
  """
  @spec get!(id :: integer() | binary()) :: AuditLogs.t()
  def get!(id), do: Repo.get!(AuditLogs, id)

  @doc """
  Fetches a single audit log matching the given parameters. Returns nil if not found.

  ## Parameters

    * `params` — a keyword list or map of fields to match.

  ## Examples

      iex> Phoexnip.AuditLogService.get_by!(city: "Metropolis")
      %Phoexnip.AuditLogs{city: "Metropolis", ...}
  """
  @spec get_by!(params :: Keyword.t(any()) | map()) :: AuditLogs.t()
  def get_by!(params), do: Repo.get_by!(AuditLogs, params)

  @doc """
  Creates a new audit log record with the given attributes.

  ## Parameters

    * `attrs` — a map of audit log fields (optional, defaults to empty map).

  ## Returns

    * `{:ok, %AuditLogs{}}` on success
    * `{:error, %Ecto.Changeset{}}` on failure
  """
  @spec create(attrs :: map()) :: {:ok, AuditLogs.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %AuditLogs{}
    |> AuditLogs.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Bulk inserts multiple audit log entries.

  ## Parameters

    * `entries` — a list of maps representing audit log fields.

  ## Returns

    * `{count, _}` — the number of entries inserted and database result.
  """
  @spec bulk_create(entries :: [map()]) :: {integer(), nil}
  def bulk_create(entries) do
    Repo.insert_all(AuditLogs, entries)
  end

  @doc """
  Retrieves audit logs for a given entity type and identifier, filtered to 'create' or 'update' actions.

  ## Parameters

    * `assigns` — a map containing:
      - `:entity_type` (string or comma-separated string of types)
      - `:id` (entity primary key)
      - `:unique_identifier` (alternate identifier)

  ## Returns

    * A list of `%AuditLogs{}` ordered by `inserted_at` descending.
  """
  @spec get_log_for_entity_type(assigns :: %{optional(atom()) => any()}) :: [AuditLogs.t()]
  def get_log_for_entity_type(assigns) do
    entity_types =
      case String.contains?(assigns.entity_type, ",") do
        true -> String.split(assigns.entity_type, ",")
        false -> [assigns.entity_type]
      end

    from(a in AuditLogs,
      where: a.entity_type in ^entity_types,
      where: a.action in ["create", "update"],
      where:
        a.entity_id == ^assigns.id or a.entity_unique_identifier == ^assigns.unique_identifier,
      select: a
    )
    |> Repo.all()
  end

  @doc """
  Creates and saves an audit log entry with JSON-encoded metadata and timestamp.

  ## Parameters

    * `entity_type` — the type of entity (string)
    * `entity_id` — the entity's primary key or identifier
    * `action` — the audit action (e.g. "create", "update")
    * `user` — a struct or map containing at least `:id` and `:name`
    * `entity_unique_identifier` — an alternate identifier for the entity
    * `changes` — a map of changes (defaults to `%{}`)
    * `previous_data` — a map of previous field values (defaults to `%{}`)
    * `meta_data` — a map of additional metadata (defaults to `%{}`)

  ## Returns

    * `{:ok, %AuditLogs{}}` on success
    * `{:error, %Ecto.Changeset{}}` on failure
  """
  @spec create_audit_log(
          entity_type :: String.t(),
          entity_id :: any(),
          action :: String.t(),
          user :: map(),
          entity_unique_identifier :: any(),
          changes :: map(),
          previous_data :: map(),
          meta_data :: map()
        ) :: {:ok, AuditLogs.t()} | {:error, Ecto.Changeset.t()}
  def create_audit_log(
        entity_type,
        entity_id,
        action,
        user,
        entity_unique_identifier,
        changes \\ %{},
        previous_data \\ %{},
        meta_data \\ %{}
      ) do
    changes_json = if map_size(changes) > 0, do: Jason.encode!(changes), else: ""
    previous_json = if map_size(previous_data) > 0, do: Jason.encode!(previous_data), else: ""
    meta_json = if map_size(meta_data) > 0, do: Jason.encode!(meta_data), else: ""

    attrs = %{
      entity_type: entity_type,
      entity_id: entity_id,
      action: action,
      user_id: user.id,
      entity_unique_identifier: entity_unique_identifier,
      user_name: if(user, do: user.name, else: ""),
      changes: changes_json,
      previous_data: previous_json,
      metadata: meta_json,
      inserted_at: DateTime.utc_now()
    }

    create(attrs)
  end
end
