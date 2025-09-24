defmodule Phoexnip.DemoJob do
  @moduledoc """
  A demonstration job module for scheduled background work.

  ## Provided functions

    * `demo_job_code/0` – logs a simple message to show a job running every minute.
    * `login/0` – handles token-based authentication, refreshing or re‑logging in as needed.
    * `demo_api_job/0` – retrieves pending tasks, calls an external API (PokeAPI), and marks each task succeeded or failed.
  """

  alias Phoexnip.SearchUtils
  alias Phoexnip.ServiceUtils
  alias Phoexnip.Settings.Tasks
  alias Phoexnip.Settings.TasksHistory

  @doc """
  Prints a demo message indicating that this job runs every minute.

  ## Examples

      iex> Phoexnip.DemoJob.demo_job_code()
      "This is a demo job that runs every 1 minute"
  """
  @spec demo_job_code() :: String.t()
  def demo_job_code do
    IO.inspect("This is a demo job that runs every 1 minute")
  end

  @doc """
  Returns a valid access token.

  If the current token is:

    1. Still valid, returns `{:ok, token}`.
    2. Expired but the refresh token is valid, refreshes and returns `{:ok, new_token}`.
    3. Both expired, logs in with credentials, stores new tokens, and returns `{:ok, new_token}`.

  ## Returns

    * `{:ok, token}` on success
    * (you could extend this to return `{:error, reason}` if login fails)
  """
  @spec login() :: {:ok, String.t()}
  def login do
    # TODO: implement token validation / refresh / credential login flow
    {:ok, "token"}
  end

  @doc """
  Executes the demo API job:

    1. Calls `login/0` to obtain a token.
    2. Logs the token and job start.
    3. Fetches pending tasks for entity `"Products"` and type `"demo_api_job"`.
    4. For each task:
       - Marks it started.
       - Sends a GET to PokeAPI (hardcoded to `"bulbasaur"`).
       - On 200 response, decodes JSON and marks the task `success`.
       - On HTTP or decoding error, marks the task `fail`.
    5. Logs how many tasks were processed.

  ## Notes

  - You can replace the hardcoded URL with dynamic task data.
  - Errors from `HTTPoison.get/1` or `Jason.decode/1` are captured and passed to the task service.
  """
  @spec demo_api_job() :: any()
  def demo_api_job do
    case login() do
      {:ok, token} ->
        IO.inspect(token, label: "token")
        task_type = "demo_api_job"
        task_entity = "Products"
        IO.inspect("START API JOB")

        tasks_to_process = fetch_tasks(task_entity, task_type)

        if length(tasks_to_process) > 0 do
          IO.inspect("Start processing: #{length(tasks_to_process)} jobs")

          Enum.each(tasks_to_process, fn task ->
            {:ok, task} = start_task(task)
            IO.inspect(task, label: "task")

            url = "https://pokeapi.co/api/v2/pokemon/bulbasaur"

            case HTTPoison.get(url) do
              {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
                case Jason.decode(body) do
                  {:ok, data} ->
                    IO.inspect(body, label: "body")
                    success_task(task, body)
                    IO.inspect(data["name"])
                    IO.inspect(data["id"])
                    IO.inspect(data["types"])

                  {:error, decode_err} ->
                    fail_task(task, "#{decode_err}")
                end

              {:ok, %HTTPoison.Response{status_code: status}} ->
                fail_task(task, "Request failed with status #{status}")

              {:error, %HTTPoison.Error{reason: reason}} ->
                fail_task(task, "HTTP request error: #{inspect(reason)}")
            end
          end)

          IO.inspect("Completed processing: #{length(tasks_to_process)} jobs")
        else
          IO.inspect("Completed processing: 0 jobs")
        end
    end
  end

  defp fetch_tasks(task_entity, task_type, max_tasks \\ 10) do
    SearchUtils.search(
      args: %{
        task_entity: task_entity,
        task_type: task_type,
        task_retry_date: [DateTime.utc_now() |> DateTime.truncate(:second), "before"],
        task_status: 0
      },
      pagination: %{page: 1, per_page: max_tasks},
      module: Tasks
    )[:entries]
  end

  defp start_task(%Tasks{} = task) do
    create_task_history(task, "Starting Task")
    ServiceUtils.update(task, %{task_status: 1})
  end

  defp fail_task(%Tasks{} = task, message) when is_binary(message) do
    retry_date =
      DateTime.utc_now()
      |> DateTime.add(30, :minute)
      |> DateTime.truncate(:second)

    create_task_history(task, message)
    ServiceUtils.update(task, %{task_status: 0, task_retry_date: retry_date})
  end

  defp success_task(%Tasks{} = task, message) when is_binary(message) do
    create_task_history(task, message)
    ServiceUtils.update(task, %{task_status: 2})
  end

  defp create_task_history(%Tasks{} = task, message) when is_binary(message) do
    history_attrs = %{
      task_id: task.id,
      task_entity: task.task_entity,
      task_entity_id: task.task_entity_id,
      task_entity_identifier: task.task_entity_identifier,
      task_type: task.task_type,
      task_status: task.task_status,
      task_retry_date: task.task_retry_date,
      message: message
    }

    ServiceUtils.create(TasksHistory, history_attrs)
  end
end
