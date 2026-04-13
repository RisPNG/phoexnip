defmodule Phoexnip.DemoJob do
  @moduledoc """
  A demonstration job module for scheduled background work.

  ## Provided functions

    * `demo_job_code/0` – logs a simple message to show a job running every minute.
  """

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
end
