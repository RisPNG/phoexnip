defmodule PhoexnipWeb.SchedulersLive.Index do
  use PhoexnipWeb, :live_view

  alias Phoexnip.Settings.SchedulersService

  @impl true
  def mount(_params, _session, socket) do
    # Check page permissions and assign initial values to the socket
    socket = Phoexnip.AuthenticationUtils.check_page_permissions(socket, "SET5", 1)

    {:ok,
     stream(
       socket
       |> assign(:page_title, "Scheduled Jobs")
       |> assign(:breadcrumb_first_segment, "Settings")
       |> assign(:breadcrumb_second_segment, "Scheduled Jobs")
       |> assign(:breadcrumb_second_link, "schedulers")
       |> assign(
         :breadcrumb_third_segment,
         nil
       )
       |> assign(:breadcrumb_fourth_segment, nil),
       :jobs,
       SchedulersService.list()
     )}
  end

  @impl true
  def handle_params(_, _url, socket) do
    # Assign page title and users collection to the socket
    {:noreply,
     socket
     |> assign(:page_title, "Scheduled Jobs")
     |> assign(:users_collection, nil)}
  end

  @impl true
  def handle_event(
        "start-job",
        %{"name" => name},
        socket
      ) do
    # Start the job and update the database
    Phoexnip.JobExecutor.start_job_if_not_running(name)

    # Stream updated jobs
    jobs = SchedulersService.list()

    socket =
      socket
      # Reset to replace all jobs in the stream
      |> stream(:jobs, jobs, reset: true)

    {:noreply, socket}
  end

  def handle_event(
        "stop-job",
        %{"name" => name},
        socket
      ) do
    # Stop the job and update the database
    Phoexnip.JobExecutor.stop_job_if_running(name)

    # Stream updated jobs
    jobs = SchedulersService.list()

    socket =
      socket
      # Reset to replace all jobs in the stream
      |> stream(:jobs, jobs, reset: true)

    {:noreply, socket}
  end

  def handle_event("run_job_manually", %{"job_to_run" => job_to_run}, socket) do
    # Execute the job manually based on the job name
    Phoexnip.JobExecutor.execute_dynamic_task(job_to_run)

    # Clear flash and show a message that the job has been triggered
    {:noreply,
     socket |> clear_flash() |> put_flash(:info, "Job " <> job_to_run <> " has been triggered.")}
  end
end
