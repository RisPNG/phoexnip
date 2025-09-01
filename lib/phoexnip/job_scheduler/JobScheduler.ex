defmodule Phoexnip.JobSchedulers do
  @moduledoc """
  A Quantum-based scheduler for the Phoexnip application.

  This module starts and supervises the background job scheduler using the
  `Quantum` library. It reads its configuration (cron definitions, jobs, etc.)
  from the `:phoexnip` OTP application environment.

  ## Configuration

  In your `config/config.exs` (or appropriate env-specific config) you can define:

      config :phoexnip, Phoexnip.JobSchedulers,
        jobs: [
          # Example:
          # {"* * * * *", {Phoexnip.JobExecutor, :start_job_from_db, [%Phoexnip.Settings.Schedulers{name: "demo_job"}]}}
        ],
        timezone: "Etc/UTC"

  ## Usage

  Simply add `Phoexnip.JobSchedulers` to your application supervision tree:

      children = [
        {Phoexnip.JobSchedulers, []},
        # ... other children
      ]

  The scheduler will then run any jobs defined in your config at their specified times.
  """
  use Quantum, otp_app: :phoexnip
end
