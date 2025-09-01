defmodule Phoexnip.Repo do
  @moduledoc """
  The primary Ecto repository for the Phoexnip application.

  This module handles database interactions using the PostgreSQL adapter.
  It is configured under the `:phoexnip` OTP application and provides all
  the standard Ecto.Repo callbacks and helpers for querying, inserting,
  updating, and deleting records.

  ## Configuration

  In your config files (e.g. `config/config.exs`), you should have:

      config :phoexnip, Phoexnip.Repo,
        username: "postgres",
        password: "postgres",
        database: "phoexnip_dev",
        hostname: "localhost",
        pool_size: 10

  ## Usage

    * Use `Phoexnip.Repo.all/2` to fetch all records matching a query.
    * Use `Phoexnip.Repo.get/3` or `get!/3` to retrieve by primary key.
    * Use `Phoexnip.Repo.insert/2`, `update/2`, and `delete/2` for changesets.
    * Use `Phoexnip.Repo.transaction/1` to wrap multiple operations atomically.
  """

  use Ecto.Repo,
    otp_app: :phoexnip,
    adapter: Ecto.Adapters.Postgres
end
