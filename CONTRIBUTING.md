Contributing

Thanks for considering a contribution! This project is a Phoenix + LiveView template intended to be a practical starting point. Please help keep it lean and useful.

How to Contribute

- Open an issue first for non-trivial changes to align on approach.
- Keep PRs focused and small; prefer several small PRs over one large one.
- Update or add module docs (`@moduledoc`, `@doc`) when behavior changes.
- Include brief rationale in commit messages and PR descriptions.

Local Development

- Setup: `mix setup` (installs deps, creates DB, migrates, builds assets)
- Run: `mix phx.server` (http://localhost:4000)
- Test: `mix test`
- Lint/Security: `mix sobelow` (dev/test only)
- Docs: `mix docs` (outputs to `doc/`)

Style

- Follow established patterns and naming in the codebase.
- Prefer explicit typespecs and descriptive `@moduledoc`s.
- Keep controllers thin; push logic into contexts/services.

Security & Secrets

- Do not commit secrets. Use environment variables and `runtime.exs`.
- If you see hard-coded demo values, replace them in your deployment.

Release Notes

- If your change affects users or API behavior, include a short entry in the PR describing the change and migration/upgrade notes if applicable.

