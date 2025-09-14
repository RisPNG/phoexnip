defmodule Phoexnip.JobExecutor do
  @moduledoc """
  Provides functions to execute, schedule, start, and stop background jobs based on
  scheduler configurations stored in the database.

  ## Features

    * `execute_job/1` — look up a named job in the database, validate it against
      a whitelist, and run it immediately.
    * `start_job_from_db/1` — take a `%Schedulers{}` struct, parse its cron expression,
      build a Quantum job, and add it to the scheduler.
    * `execute_dynamic_task/1` — dynamically invoke a function in `Phoexnip.Jobs`
      by its name.
    * `start_job_if_not_running/1` — check if a job is already scheduled; if not,
      mark it active and schedule it.
    * `stop_job_if_running/1` — check if a job is running; if so, mark it inactive
      and remove it from the scheduler.
  """

  alias Phoexnip.Settings.Schedulers
  alias Phoexnip.ServiceUtils

  @allowed_jobs %{
    "quality_images_clean_up" => :quality_images_clean_up,
    "demo_job" => :demo_job,
    "demo_api_job" => :demo_api_job,
    "nike_acs" => :nike_acs,
    "nike_acs_attachment" => :nike_acs_attachment
  }

  @doc """
  Executes the job identified by `name` immediately.

  1. Fetches the scheduler record by name.
  2. Validates that the name is in the `@allowed_jobs` whitelist.
  3. Applies the corresponding zero‑arity function in `Phoexnip.Jobs`.

  Returns `:ok` if the job runs successfully, or `:error` if the name is not found,
  not allowed, or execution raises.
  """
  @spec execute_job(String.t()) :: :ok | :error
  def execute_job(name) do
    case ServiceUtils.get_by(Schedulers, %{name: name}) do
      nil ->
        IO.inspect("No job found with name #{name}")
        :error

      scheduler ->
        case Map.get(@allowed_jobs, scheduler.name) do
          nil ->
            IO.inspect("Invalid job name: #{scheduler.name}")
            :error

          fun ->
            try do
              apply(Phoexnip.Jobs, fun, [])
              :ok
            rescue
              error ->
                IO.inspect("Failed to execute job: #{inspect(error)}")
                :error
            end
        end
    end
  end

  @doc """
  Schedules a job from an existing `%Schedulers{}` struct:

  1. Parses the cron expression.
  2. Builds a `Quantum.Job`:
     - Sets the approved job atom as name.
     - Applies the parsed cron schedule.
     - Sets the task to call `execute_dynamic_task/1` with `scheduler.name`.
     - Configures timezone and overlap prevention.
  3. Adds it to `Phoexnip.JobSchedulers`.

  Logs errors for invalid job names or cron parse failures.
  """
  @spec start_job_from_db(Schedulers.t()) :: :ok | :error
  def start_job_from_db(%Schedulers{} = scheduler) do
    cron_expression = scheduler.cron_expression
    current_timezone = Timex.Timezone.local().full_name

    case Map.get(@allowed_jobs, scheduler.name) do
      nil ->
        IO.inspect("Invalid job name: #{scheduler.name}")
        :error

      job_atom ->
        case Crontab.CronExpression.Parser.parse(cron_expression) do
          {:ok, parsed_cron} ->
            Phoexnip.JobSchedulers.new_job()
            |> Quantum.Job.set_name(job_atom)
            |> Quantum.Job.set_schedule(parsed_cron)
            |> Quantum.Job.set_task({__MODULE__, :execute_dynamic_task, [scheduler.name]})
            |> Quantum.Job.set_timezone(current_timezone)
            |> Quantum.Job.set_overlap(false)
            |> Phoexnip.JobSchedulers.add_job()

          {:error, reason} ->
            IO.inspect("Failed to parse cron expression #{cron_expression}: #{inspect(reason)}")
            :error
        end
    end
  end

  @doc """
  Dynamically executes the function mapped to `task_name` in `@allowed_jobs`
  by calling zero‑arity functions in `Phoexnip.Jobs`.

  - If the task name is not in the whitelist, logs an error.
  - If the function is not exported in `Phoexnip.Jobs`, logs an error.

  Returns whatever the underlying function returns, or `nil` if invalid.
  """
  @spec execute_dynamic_task(String.t()) :: term()
  def execute_dynamic_task(task_name) do
    case Map.get(@allowed_jobs, task_name) do
      nil ->
        IO.inspect("Error: Task #{task_name} is not defined in the allowed jobs list")

      function_atom ->
        _ = Code.ensure_loaded?(Phoexnip.Jobs)

        if function_exported?(Phoexnip.Jobs, function_atom, 0) do
          apply(Phoexnip.Jobs, function_atom, [])
        else
          IO.inspect("Error: Task #{task_name} is not defined in Phoexnip.Jobs")
        end
    end
  end

  @doc """
  Starts the job identified by `job_name` if it’s not already scheduled:

  1. Validates `job_name` against the whitelist.
  2. Checks Phoexnip.JobSchedulers.find_job/1.
  3. If not found, fetches the scheduler, marks its status `1`, and calls
     `start_job_from_db/1`.

  Returns `:ok` if the job was started or already running, or `:error` otherwise.
  """
  @spec start_job_if_not_running(String.t()) :: :ok | :error
  def start_job_if_not_running(job_name) do
    case Map.get(@allowed_jobs, job_name) do
      nil ->
        IO.inspect("Invalid job name: #{job_name}")
        :error

      allowed_job_atom ->
        case Phoexnip.JobSchedulers.find_job(allowed_job_atom) do
          nil ->
            case ServiceUtils.get_by(Schedulers, %{name: job_name}) do
              nil ->
                IO.inspect("No job found with name #{job_name}")
                :error

              scheduler ->
                ServiceUtils.update(scheduler, %{status: 1})
                start_job_from_db(scheduler)
                IO.inspect("Job #{job_name} started.")
                :ok
            end

          _job ->
            IO.inspect("Job #{job_name} is already running.")
            :ok
        end
    end
  end

  @doc """
  Stops the job identified by `job_name` if it’s currently scheduled:

  1. Validates `job_name` against the whitelist.
  2. Checks Phoexnip.JobSchedulers.find_job/1.
  3. If running, fetches the scheduler, updates its status to `0`,
     deletes the job from the scheduler, and logs success.

  Returns `:ok` if the job was stopped or not running, or `:error` on failure.
  """
  @spec stop_job_if_running(String.t()) :: :ok | :error
  def stop_job_if_running(job_name) do
    case Map.get(@allowed_jobs, job_name) do
      nil ->
        IO.inspect("Invalid job name: #{job_name}")
        :error

      job_name_atom ->
        case Phoexnip.JobSchedulers.find_job(job_name_atom) do
          nil ->
            IO.inspect("Job #{job_name} is not running.")
            :ok

          _job ->
            case ServiceUtils.get_by(Schedulers, %{name: job_name}) do
              nil ->
                IO.inspect("No scheduler found with the name #{job_name}.")
                :error

              scheduler ->
                case ServiceUtils.update(scheduler, %{status: 0}) do
                  {:ok, _} ->
                    Phoexnip.JobSchedulers.delete_job(job_name_atom)
                    IO.inspect("Job #{job_name} stopped successfully.")
                    :ok

                  {:error, error} ->
                    IO.inspect("Failed to update scheduler status: #{inspect(error)}")
                    :error
                end
            end
        end
    end
  end
end
