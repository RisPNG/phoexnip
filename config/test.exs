import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1
config :phoexnip, :start_job_starter, false
# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :phoexnip, Phoexnip.Repo,
  url:
    System.get_env("DATABASE_URL") ||
      "ecto://postgres:postgres@localhost/phoexnip_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  # Increase query timeout
  timeout: 60_000,
  # Time to wait before considering pool saturation
  queue_target: 50,
  # Wait time before retrying to check out connections
  queue_interval: 1_000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :phoexnip, PhoexnipWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "JhWY1NeV4HvATmtzHzmsPSkGiozCu+nyFiQdJ6VztpkfT25S/7hv9cZLmoI54gr7",
  server: false

# In test we don't send emails
config :phoexnip, Phoexnip.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
