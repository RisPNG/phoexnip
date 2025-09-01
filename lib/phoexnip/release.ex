defmodule Phoexnip.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :phoexnip

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  # Since it can be used for RCE (Remote Code Execution) attacks, we should not leave this in the final production build.
  # If needed uncomment push, do the seeds, then comment it back out.
  # def seed do
  #   load_app()

  #   # Ensure Repo is started before running seeds
  #   {:ok, _} = Application.ensure_all_started(:ecto)
  #   {:ok, _} = Application.ensure_all_started(:postgrex)
  #   Phoexnip.Repo.start_link()

  #   path = Application.app_dir(@app, "priv/repo/seeds.exs")

  #   if File.exists?(path) do
  #     IO.puts("Running seeds script...")
  #     Code.eval_file(path)
  #   else
  #     IO.puts("No seeds.exs found, skipping.")
  #   end
  # end

  defp load_app do
    Application.load(@app)
  end
end
