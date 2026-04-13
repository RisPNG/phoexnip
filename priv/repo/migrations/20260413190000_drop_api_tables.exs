defmodule Phoexnip.Repo.Migrations.DropApiTables do
  use Ecto.Migration

  def change do
    execute("DELETE FROM task_history WHERE task_type = 'demo_api_job'")
    execute("DELETE FROM task WHERE task_type = 'demo_api_job'")
    execute("DELETE FROM schedulers WHERE name = 'demo_api_job'")

    drop_if_exists unique_index(:api_credential, [:job])
    drop_if_exists table(:api_credential)

    drop_if_exists index(:api_key, [:given_to])
    drop_if_exists unique_index(:api_key, [:key])
    drop_if_exists table(:api_key)
  end
end
