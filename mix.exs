defmodule Phoexnip.MixProject do
  use Mix.Project

  # define it once:
  @version "0.1.0"

  def project do
    [
      app: :phoexnip,
      version: @version,
      elixir: ">= 1.18.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      compilers: Mix.compilers() ++ [:phoenix_swagger],
      deps: deps(),
      dialyzer: [
        plt_core_path: "priv/plts/core.plt",
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:ex_unit]
      ],
      releases: releases(),
      docs: [
        output: "doc/v#{@version}",
        filter_modules:
          ~r/^(?!Elixir\.PhoexnipWeb\..*(?:Live|Report|Plugs|UserAuth|UserLoginLive|UserResetPasswordLive|UserSessionController|UserSettingsLive|Telemetry|Router|Plugs|Presence|Home|Layouts|Endpoint|DetailComponent|PresenceTracker)(?:\.(?:Index|New|Show|UserManual|FormComponent|SessionExpiryHook))?$).*$/
      ]
    ]
  end

  def releases do
    [
      phoexnip: [
        burrito: [
          targets: [
            macos: [os: :darwin, cpu: :x86_64],
            linux: [os: :linux, cpu: :x86_64],
            windows: [os: :windows, cpu: :x86_64]
          ]
        ],
        applications: [phoexnip: :permanent],
        steps: [:assemble, &Burrito.wrap/1]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Phoexnip.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  def deps do
    [
      {:bandit, ">= 1.5.0"},
      {:bcrypt_elixir, ">= 3.0.0"},
      {:burrito, ">= 1.0.0"},
      {:dialyxir, ">= 1.4.0", only: [:dev], runtime: false},
      {:dns_cluster, ">= 0.1.1"},
      {:ecto_sql, ">= 3.10.0"},
      {:elixlsx, ">= 0.6.0"},
      {:esbuild, ">= 0.8.0", runtime: Mix.env() == :dev},
      {:ex_doc, ">= 0.37.0"},
      {:ex_json_schema, ">= 0.5.0"},
      {:faker, ">= 0.18.0", only: [:dev]},
      {:finch, ">= 0.13.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:gen_smtp, ">= 1.2.0"},
      {:gettext, ">= 0.20.0"},
      {:heroicons, github: "tailwindlabs/heroicons", sparse: "optimized", app: false, compile: false, depth: 1},
      {:httpoison, ">= 1.8.0"},
      {:jason, ">= 1.2.0"},
      {:live_debugger, ">= 0.3.0", only: :dev},
      {:live_select, ">= 1.0.0"},
      {:pdf_generator, ">= 0.6.0"},
      {:phoenix, ">= 1.7.14"},
      {:phoenix_ecto, ">= 4.5.0"},
      {:phoenix_html, ">= 4.1.0"},
      {:phoenix_live_dashboard, ">= 0.8.3"},
      {:phoenix_live_reload, ">= 1.2.0", only: :dev},
      {:phoenix_live_view, ">= 1.0.0"},
      {:phoenix_swagger, ">= 0.8.0"},
      {:plug, ">= 1.14.0"},
      {:postgrex, ">= 0.0.0"},
      {:qr_code, ">= 3.0.0"},
      {:quantum, ">= 3.5.0"},
      {:req, ">= 0.5.0"},
      {:sobelow, ">= 0.13.0", only: [:dev, :test], runtime: false},
      {:stb_image, ">= 0.6.9"},
      {:styler, ">= 1.4.0", only: [:dev, :test], runtime: false},
      {:swoosh, ">= 1.18.0"},
      {:tailwind, ">= 0.2.0", runtime: Mix.env() == :dev},
      {:telemetry_metrics, ">= 1.0.0"},
      {:telemetry_poller, ">= 1.0.0"},
      {:timex, ">= 3.0.0"},
      {:xlsx_reader, ">= 0.8.0", git: "https://github.com/weih-kahoot/xlsx_reader.git", branch: "otp-28-compatibility"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": [
        "ecto.drop",
        "ecto.setup"
      ],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind phoexnip", "esbuild phoexnip"],
      "assets.deploy": [
        "tailwind phoexnip --minify",
        "esbuild phoexnip --minify",
        "phx.digest"
      ],
      "assets.clear": [
        "cmd npx rimraf node_modules _build deps .elixir_ls priv/static/swagger.json priv/static/assets erl_crash.dump priv/static/cache_manifest.json"
      ],
      "assets.rebuild": [
        "deps.clean --all",
        "clean --deps",
        "clean",
        "deps.get",
        "phx.digest.clean --all",
        "cmd npm cache clean --force",
        "cmd npm prune",
        "cmd npm install",
        "cmd npm ci",
        "deps.compile",
        ~S[cmd bash -c 'PGUSER=postgres psql -h localhost -p 5432 -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND usename != '\''postgres'\'';"'],
        "ecto.reset",
        "assets.setup",
        "assets.build",
        "tailwind phoexnip --minify",
        "esbuild phoexnip --minify"
      ],
      reset: [
        "cmd git reset",
        "assets.clear",
        "cmd git rm --cached -r .",
        "cmd git add .",
        "assets.rebuild",
        "cmd git reset"
      ],
      "reset.hard": [
        "cmd git reset",
        "assets.clear",
        "cmd git clean -xfd",
        "cmd git rm --cached -r .",
        "cmd git add .",
        "cmd git clean -xfd",
        "assets.rebuild",
        "cmd git reset"
      ],
      "reset.update": [
        "cmd git reset",
        "cmd npx rimraf node_modules package-lock.json _build deps .elixir_ls priv/static/swagger.json priv/static/assets erl_crash.dump mix.lock priv/static/cache_manifest.json",
        "cmd git rm --cached -r .",
        "cmd git add .",
        "assets.rebuild",
        "cmd git reset",
        "deps.get",
        "deps.update --all",
        "deps.compile"
      ]
    ]
  end
end
