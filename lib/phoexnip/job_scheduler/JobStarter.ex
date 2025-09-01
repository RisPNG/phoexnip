defmodule Phoexnip.JobStarter do
  @moduledoc """
  A GenServer responsible for initializing and starting all active
  scheduled jobs when the application boots.

  On startup it waits briefly, then:
    1. Fetches all active scheduler entries from the database via `SchedulersService.list_active/0`.
    2. Invokes `Phoexnip.JobExecutor.start_job_from_db/1` for each scheduler to register them
       with the Quantum scheduler.
  """

  use GenServer

  alias Phoexnip.Settings.SchedulersService
  alias Phoexnip.JobExecutor

  @doc """
  Starts the `Phoexnip.JobStarter` GenServer and registers it under its module name.

  ## Parameters

    - `_args` — ignored.

  ## Returns

    - `{:ok, pid}` on success
    - `{:error, reason}` on failure
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  @doc """
  Initializes the GenServer state and schedules the `:init_jobs` message.

  Sends `:init_jobs` to self after 1 second to trigger job initialization.

  ## Returns

    - `{:ok, initial_state}` where `initial_state` is an empty list.
  """
  @spec init(term()) :: {:ok, list()}
  def init(_) do
    Process.send_after(self(), :init_jobs, 1_000)
    {:ok, []}
  end

  @impl true
  @doc """
  Handles the `:init_jobs` message by:

    1. Fetching all active scheduler records via `SchedulersService.list_active/0`.
    2. Starting each job using `JobExecutor.start_job_from_db/1`.

  ## Parameters

    - `:init_jobs` — the message atom
    - `state` — the current process state (a list, unused here)

  ## Returns

    - `{:noreply, state}` to continue running with the same state.
  """
  @spec handle_info(:init_jobs, list()) :: {:noreply, list()}
  def handle_info(:init_jobs, state) do
    active_scheduler = SchedulersService.list_active()
    Enum.each(active_scheduler, &JobExecutor.start_job_from_db/1)
    {:noreply, state}
  end
end
