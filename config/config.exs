# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :phoexnip,
  ecto_repos: [Phoexnip.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :phoexnip, PhoexnipWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PhoexnipWeb.ErrorHTML, json: PhoexnipWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Phoexnip.PubSub,
  live_view: [
    signing_salt:
      if config_env() == :prod do
        System.get_env("LIVE_VIEW_SALT")
      else
        "0XBNM1drs9v0qUcivEb+b5Uy+CVe6PG5"
      end
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :phoexnip, Phoexnip.Mailer, adapter: Swoosh.Adapters.Local

# Default mailer From header (override in runtime.exs via env vars if needed)
config :phoexnip, :mailer_from, {"Phoexnip", "noreply@example.com"}

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  phoexnip: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  phoexnip: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :phoexnip, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      router: PhoexnipWeb.Router,
      endpoint: PhoexnipWeb.Endpoint,
      # Define the base path for the API
      basePath: "/api",
      security_definitions: %{
        api_key: [
          type: "apiKey",
          name: "x-api-key",
          in: "header"
        ]
      }
    ]
  }

# Swagger configuration test
config :phoenix_swagger, json_library: Jason

config :phoexnip, Phoexnip.JobSchedulers, jobs: []
