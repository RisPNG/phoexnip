defmodule Phoexnip.Jobs do
  @moduledoc """
  Defines the set of allowable tasks that can be executed by `Phoexnip.JobExecutor`.
  Each function maps a named job (as stored in the database) to the actual implementation
  module and function that performs the work.
  """

  @doc """
  Handles the `:demo_job` task by delegating to `Phoexnip.DemoJob.demo_job_code/0`.
  """
  @spec demo_job() :: any()
  def demo_job do
    Phoexnip.DemoJob.demo_job_code()
  end

  @doc """
  Handles the `:demo_api_job` task by delegating to `Phoexnip.DemoJob.demo_api_job/0`.
  """
  @spec demo_api_job() :: any()
  def demo_api_job do
    Phoexnip.DemoJob.demo_api_job()
  end
end
