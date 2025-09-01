defmodule Phoexnip.Application do
  @moduledoc false

  use Application
  @start_job_starter Application.compile_env(:phoexnip, :start_job_starter, Mix.env() != :test)
  @impl true
  def start(_type, _args) do
    children =
      [
        PhoexnipWeb.Telemetry,
        Phoexnip.Repo,
        # {DNSCluster, query: Application.get_env(:phoexnip, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Phoexnip.PubSub},
        PhoexnipWeb.Presence,
        # Start the Finch HTTP client for sending emails
        {Finch, name: Phoexnip.Finch},
        # Add ApiKeyCache to the supervision tree
        {ApiKeyCache, []},
        # Start to serve requests, typically the last entry
        PhoexnipWeb.Endpoint,
        Phoexnip.JobSchedulers
      ] ++ job_starter_child()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Phoexnip.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoexnipWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp job_starter_child do
    if @start_job_starter do
      [{Phoexnip.JobStarter, []}]
    else
      []
    end
  end
end
