defmodule Phoexnip.AuditLogService do
  @moduledoc """
  Thin wrappers around shared utilities for AuditLogs.

  This module intentionally stays minimal by delegating to `SearchUtils`
  and `ServiceUtils`, keeping only behavior that composes attributes
  or complex filters specific to audit logging.
  """

  alias Phoexnip.AuditLogs
  alias Phoexnip.SearchUtils
  alias Phoexnip.ServiceUtils

  @doc """
  Retrieves audit logs for one or more `entity_type`s and a target entity,
  limited to action types "create" or "update", ordered by newest first.

  Accepts assigns with keys:
  - `:entity_type` – string or comma‑separated string
  - `:id` – integer ID
  - `:unique_identifier` – alternative identifier
  """
  @spec get_log_for_entity_type(assigns :: %{optional(atom()) => any()} | map()) :: [
          AuditLogs.t()
        ]
  def get_log_for_entity_type(assigns) when is_map(assigns) do
    entity_type_val = Map.get(assigns, :entity_type) || Map.get(assigns, "entity_type", "")

    entity_types =
      cond do
        is_binary(entity_type_val) and String.contains?(entity_type_val, ",") ->
          String.split(entity_type_val, ",")

        is_binary(entity_type_val) and entity_type_val != "" ->
          [entity_type_val]

        is_list(entity_type_val) ->
          entity_type_val

        true ->
          []
      end

    id = Map.get(assigns, :id) || Map.get(assigns, "id")
    uid = Map.get(assigns, :unique_identifier) || Map.get(assigns, "unique_identifier")

    result =
      SearchUtils.search(
        module: AuditLogs,
        args: %{
          # exact matches for strings
          entity_type: entity_types ++ ["exact_or"],
          action: ["create", "update", "exact_or"],
          # either entity_id equals or entity_unique_identifier equals
          _or: %{entity_id: id, entity_unique_identifier: uid}
        },
        pagination: %{},
        order_by: :inserted_at,
        order_method: :desc,
        preload: []
      )

    result.entries
  end

  @doc """
  Creates an audit log entry, encoding maps as JSON strings and stamping `inserted_at`.
  Delegates persistence to `ServiceUtils.create/2`.
  """
  @spec create_audit_log(
          entity_type :: String.t(),
          entity_id :: any(),
          action :: String.t(),
          user :: map() | struct() | nil,
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
    changes_json =
      if is_map(changes) and map_size(changes) > 0, do: Jason.encode!(changes), else: ""

    previous_json =
      if is_map(previous_data) and map_size(previous_data) > 0,
        do: Jason.encode!(previous_data),
        else: ""

    meta_json =
      if is_map(meta_data) and map_size(meta_data) > 0, do: Jason.encode!(meta_data), else: ""

    user_id =
      case user do
        nil -> nil
        %{} -> Map.get(user, :id) || Map.get(user, "id")
        _ -> nil
      end

    user_name =
      case user do
        nil -> ""
        %{} -> Map.get(user, :name) || Map.get(user, "name") || ""
        _ -> ""
      end

    attrs = %{
      entity_type: entity_type,
      entity_id: entity_id,
      action: action,
      user_id: user_id,
      entity_unique_identifier: entity_unique_identifier,
      user_name: user_name,
      changes: changes_json,
      previous_data: previous_json,
      metadata: meta_json,
      inserted_at: DateTime.utc_now()
    }

    ServiceUtils.create(AuditLogs, attrs)
  end
end
