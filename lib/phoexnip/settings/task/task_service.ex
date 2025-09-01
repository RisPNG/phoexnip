defmodule Phoexnip.Settings.TasksService do
  @moduledoc """
  Service functions for managing `Tasks` and recording `TasksHistory` entries.

  Provides:

    * `list/0`               – returns all tasks
    * `get!/1`              – fetches a task by id, raises if not found
    * `create/1`            – creates a new task
    * `get_tasks_for_job/3` – retrieves pending tasks for a given entity and type
    * `start_task/1`        – marks a task as in-progress and logs history
    * `fail_task/2`         – marks a task as failed (pending retry) and logs history
    * `success_task/2`      – marks a task as successful and logs history
    * `update/2`            – updates an existing task
    * `create_history/2`    – creates a history record for a task
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Settings.Tasks
  alias Phoexnip.Settings.TasksHistory

  @doc """
  Returns all `Tasks` records.
  """
  @spec list() :: [Tasks.t()]
  def list do
    Repo.all(Tasks)
  end

  @doc """
  Retrieves a `Tasks` by its `id`.

  Raises `Ecto.NoResultsError` if no record is found.
  """
  @spec get!(id :: term()) :: Tasks.t()
  def get!(id), do: Repo.get!(Tasks, id)

  @doc """
  Creates a new `Tasks` record with the given attributes.

  Returns `{:ok, task}` on success or `{:error, changeset}` on failure.
  """
  @spec create(attrs :: map()) :: {:ok, Tasks.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %Tasks{}
    |> Tasks.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Retrieves pending `Tasks` for a given entity and type, up to `max_tasks` entries.
  """
  @spec get_tasks_for_job(
          task_entity :: String.t(),
          task_type :: String.t(),
          max_tasks :: non_neg_integer()
        ) :: [Tasks.t()]
  def get_tasks_for_job(task_entity, task_type, max_tasks \\ 10) do
    Phoexnip.SearchUtils.search(
      args: %{
        task_entity: task_entity,
        task_type: task_type,
        task_retry_date: [DateTime.utc_now() |> DateTime.truncate(:second), "before"],
        task_status: 0
      },
      pagination: %{page: 1, per_page: max_tasks},
      module: Phoexnip.Settings.Tasks
    )[:entries]
  end

  @doc """
  Marks a task as in-progress (status 1) and logs the start event to history.

  Returns `{:ok, task}` or `{:error, changeset}` from the update.
  """
  @spec start_task(task :: Tasks.t()) :: {:ok, Tasks.t()} | {:error, Ecto.Changeset.t()}
  def start_task(%Tasks{} = task) do
    args = %{task_status: 1}
    create_history(task, "Starting Task")
    Phoexnip.Settings.TasksService.update(task, args)
  end

  @doc """
  Marks a task as failed (status 0), schedules a retry 30 minutes later, and logs the failure.

  Returns `{:ok, task}` or `{:error, changeset}` from the update.
  """
  @spec fail_task(task :: Tasks.t(), message :: String.t()) ::
          {:ok, Tasks.t()} | {:error, Ecto.Changeset.t()}
  def fail_task(%Tasks{} = task, message) do
    args = %{
      task_status: 0,
      task_retry_date:
        DateTime.utc_now()
        |> DateTime.add(30, :minute)
        |> DateTime.truncate(:second)
    }

    create_history(task, message)
    Phoexnip.Settings.TasksService.update(task, args)
  end

  @doc """
  Marks a task as successful (status 2) and logs the success message.

  Returns `{:ok, task}` or `{:error, changeset}` from the update.
  """
  @spec success_task(task :: Tasks.t(), message :: String.t()) ::
          {:ok, Tasks.t()} | {:error, Ecto.Changeset.t()}
  def success_task(%Tasks{} = task, message) do
    args = %{task_status: 2}

    create_history(task, message)
    Phoexnip.Settings.TasksService.update(task, args)
  end

  @doc """
  Updates an existing `Tasks` record with the given attributes.

  Returns `{:ok, task}` or `{:error, changeset}`.
  """
  @spec update(task :: Tasks.t(), attrs :: map()) ::
          {:ok, Tasks.t()} | {:error, Ecto.Changeset.t()}
  def update(%Tasks{} = task, attrs) do
    task
    |> Tasks.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a `TasksHistory` entry for the given task and message.

  Returns `{:ok, history}` or `{:error, changeset}`.
  """
  @spec create_history(task :: Tasks.t(), message :: String.t()) ::
          {:ok, TasksHistory.t()} | {:error, Ecto.Changeset.t()}
  def create_history(%Tasks{} = task, message) do
    attrs = %{
      task_id: task.id,
      task_entity: task.task_entity,
      task_entity_id: task.task_entity_id,
      task_entity_identifier: task.task_entity_identifier,
      task_type: task.task_type,
      task_status: task.task_status,
      task_retry_date: task.task_retry_date,
      message: message
    }

    %TasksHistory{}
    |> TasksHistory.changeset(attrs)
    |> Repo.insert()
  end
end
