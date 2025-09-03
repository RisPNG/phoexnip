# Phoexnip

An opinionated Phoenix + LiveView template with authentication, roles/permissions, Swagger API docs, and a handful of utilities (job scheduler, audit logs, mailer, etc.). Use this as a starting point for new apps.

## Requirements

- Elixir/Erlang (see `.tool-versions` or `mise.toml` if present)
- PostgreSQL 14+
- Node.js 18+ (for assets)

You can manage versions with `asdf` or `mise` if you prefer. The project includes Mix aliases to streamline common tasks.

## Quick Start

1) Install dependencies and set up the database

```bash
mix deps.get
mix ecto.setup
cd assets && npm install && cd -
```

2) Run the server

```bash
mix phx.server
```

App runs at `http://localhost:4000`.

## Common Tasks

- Setup everything: `mix setup`
- Reset DB: `mix ecto.reset`
- Run tests: `mix test`
- Build assets: `mix assets.build`
- Deploy assets: `mix assets.deploy`

See `mix.exs` for additional aliases such as `assets.rebuild` and `reset.*`.

## Configuration

- Environment-specific config is in `config/*.exs`.
- Swagger host is configured via `config/runtime.exs` under `:phoexnip, :swagger_host`.
- Update mailer, storage, and URLs per environment as needed.

## API Docs (Swagger)

- Swagger UI is available at `/api/v1/swagger/` when configured.
- Security: API endpoints expect an `x-api-key` header where required.

## Auth, Roles, and Permissions

- Authentication utilities live under `lib/phoexnip_web/user_auth.ex` and `lib/phoexnip/utils/authentication_utils.ex`.
- Roles/permissions are under `lib/phoexnip/settings/roles/*`.

## Schedulers

- Quantum-based scheduler is configured under `:phoexnip, Phoexnip.JobSchedulers`.
- Add or manage jobs in config files; see `lib/phoexnip/job_scheduler/*`.

## Code Quality

- Security scanning: `mix sobelow` (dev/test only)
- Dialyzer: configured in `mix.exs` (may require PLTs build)
- Docs: `mix docs` (outputs to `doc/`)

## Contributing

- Follow existing code style and module documentation patterns.
- Update or add module docs (`@moduledoc`/`@doc`) when changing behavior.

## Notes

This repository was generalized from an internal project. Any brand- or environment-specific references are intentionally removed from documentation; if you find one in code or UI strings, feel free to update it to suit your deployment.

## Development Workflow

1. Create a new branch from the latest master with ``git switch -c <YOUR NEW FEATURE/UPDATE>``. Commit to this branch as you please.
2. Once you feel confident this features or update go to our gitlab and create a merge request. Ensure we squash commits to keep the master branch clean. And write a proper commit message summarizing all your changes.
3. When approved, you are allowed to merge it to master.

To approve a request the reviewer has to do the following

1. Test the feature / update.
2. Check if any documentation is updated if nessasry (techincal or user manual using Scribe)
3. Ensure the API and Swagger documentation are updated if required.
4. Check if any new tests are updated / added and make sure they succeed.
5. Ensure the CI/CD pipeline successed any fails is an automatic non approved.
