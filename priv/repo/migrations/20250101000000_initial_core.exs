defmodule Phoexnip.Repo.Migrations.InitialCore do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :email, :citext, null: false
      add :username, :text
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime
      add :name, :text, null: false
      add :image_url, :text
      add :group, :text
      add :phone, :text
      add :super_user, :boolean, default: false, null: false

      add :credential, :text
      add :location, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])

    # Seed: Super user account
    execute(
      """
      INSERT INTO users (email, hashed_password, name, super_user, inserted_at, updated_at)
      VALUES (
        'superuser@poppybit.com',
        '$2b$12$0/lXdVgCb/.TReOZkVMqXO0J1cNMe8gcb7Om9BAjDXf4W3ZZa.yD2',
        'Admin',
        TRUE,
        timezone('UTC', now()),
        timezone('UTC', now())
      )
      ON CONFLICT (email) DO NOTHING
      """,
      """
      DELETE FROM users WHERE email = 'superuser@poppybit.com'
      """
    )

    create table(:user_token) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:user_token, [:user_id])
    create unique_index(:user_token, [:context, :token])

    create table(:roles) do
      add :name, :string
      add :description, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:name])

    execute(
      """
      INSERT INTO roles (name, inserted_at, updated_at)
      VALUES (
        'Superuser',
        timezone('UTC', now()),
        timezone('UTC', now())
      )
      ON CONFLICT (name) DO NOTHING
      """,
      """
      DELETE FROM roles WHERE name = 'Superuser'
      """
    )

    create table(:role_permissions) do
      add :permission, :integer
      add :sitemap_code, :string
      add :sitemap_name, :string
      add :sitemap_level, :integer
      add :sitemap_parent, :string
      add :sitemap_url, :string
      add :sequence, :integer
      add :sitemap_description, :string
      add :role_id, references(:roles, on_delete: :delete_all), null: false
    end

    execute(
      """
      INSERT INTO role_permissions (sitemap_code, sitemap_name, sitemap_level, sitemap_description, sitemap_parent, sitemap_url, sequence, permission, role_id)
      VALUES
        ('H',    'Home',                0, NULL,    NULL,  NULL,                          0, 16, 1),
        ('SET',  'Settings',            0, NULL,    NULL,  NULL,                      90000, 16, 1),
        ('SET1', 'Users',               1, NULL,   'SET',  'users',                   91000, 16, 1),
        ('SET2', 'Roles',               1, NULL,   'SET',  'roles',                   92000, 16, 1),
        ('SET3', 'Master Data',         1, NULL,   'SET',  'master_data',             93000, 16, 1),
        ('SET3A','Currencies',          2, NULL,  'SET3',  'master_data/currencies',    93100, 16, 1),
        ('SET3B','Groups',              2, NULL,  'SET3',  'master_data/groups',    93200, 16, 1),
        ('SET4', 'Organisation Information', 1, NULL,   'SET',  'organisation_information', 94000, 16, 1),
        ('SET5', 'Scheduled Jobs',      1, NULL,   'SET',  'schedulers',              95000, 16, 1),
        ('SET6', 'Reports',             1, NULL,   'SET',  'settings_reports',        96000, 16, 1),
        ('SET6A','User Login Report',   2, NULL,  'SET6',  'settings_reports/user_login_report', 96100, 16, 1)
      ON CONFLICT DO NOTHING
      """,
      """
      DELETE FROM role_permissions WHERE sitemap_code IN ('H','SET','SET1','SET2','SET3','SET3A','SET4','SET5','SET6','SET6A')
      """
    )

    create table(:user_roles) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :belongs_in_role, :boolean
      add :role_name, :string
    end

    create table(:organisation_info) do
      add :name, :string
      add :registration_number, :string
      add :gst_number, :string
      add :socso_number, :string
      add :pcb_number, :string
      add :phone, :string
      add :fax, :string
      add :website, :string
      add :email, :string
      add :currency, :string

      timestamps(type: :utc_datetime)
    end

    create table(:address) do
      add :attn, :string
      add :attn2, :string
      add :guid, :string
      add :line1, :string
      add :line2, :string
      add :line3, :string
      add :postcode, :string
      add :city, :string
      add :state, :string
      add :country, :string
      add :category, :string
      add :sequence, :integer
      add :supplier_mco, :string

      add :organisation_info_id, references(:organisation_info, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create table(:sitemap) do
      add :code, :string
      add :displayname, :string
      add :level, :integer
      add :description, :string
      add :parent, :string
      add :url, :string
      add :sequence, :integer
    end

    # Seed: Sitemap entries
    execute(
      """
      INSERT INTO sitemap (code, displayname, level, description, parent, url, sequence)
      VALUES
        ('H',    'Home',                0, NULL,    NULL,  NULL,                          0),
        ('SET',  'Settings',            0, NULL,    NULL,  NULL,                      90000),
        ('SET1', 'Users',               1, NULL,   'SET',  'users',                   91000),
        ('SET2', 'Roles',               1, NULL,   'SET',  'roles',                   92000),
        ('SET3', 'Master Data',         1, NULL,   'SET',  'master_data',             93000),
        ('SET3A','Currencies',          2, NULL,  'SET3',  'master_data/currencies',    93100),
        ('SET3B','Groups',              2, NULL,  'SET3',  'master_data/groups',    93200),
        ('SET4', 'Organisation Information', 1, NULL,   'SET',  'organisation_information', 94000),
        ('SET5', 'Scheduled Jobs',      1, NULL,   'SET',  'schedulers',              95000),
        ('SET6', 'Reports',             1, NULL,   'SET',  'settings_reports',        96000),
        ('SET6A','User Login Report',   2, NULL,  'SET6',  'settings_reports/user_login_report', 96100)
      ON CONFLICT DO NOTHING
      """,
      """
      DELETE FROM sitemap WHERE code IN ('H','SET','SET1','SET2','SET3','SET3A','SET4','SET5','SET6','SET6A')
      """
    )

    create table(:api_key) do
      add :given_to, :string
      add :key, :string, null: false
      add :valid_until, :utc_datetime
      add :refresh_key, :string
      add :refresh_until, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_key, [:key])
    create index(:api_key, [:given_to])

    create table(:api_credential) do
      add :job, :string
      add :credential, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_credential, [:job])

    create table(:audit_logs) do
      add :entity_type, :string, null: false
      add :entity_id, :integer, null: false
      add :entity_unique_identifier, :string
      add :action, :string, null: false
      add :user_id, :integer
      add :user_name, :string
      add :changes, :text
      add :previous_data, :text
      add :metadata, :text
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:audit_logs, [:entity_type, :entity_id], name: :idx_entity_type_entity_id)
    create index(:audit_logs, [:entity_unique_identifier], name: :idx_entity_unique_identifier)

    create table(:task) do
      add :task_entity, :string
      add :task_entity_id, :integer
      add :task_entity_identifier, :string
      add :task_type, :string
      add :task_status, :integer
      add :task_retry_date, :utc_datetime
      add :task_initiator, :string

      timestamps(type: :utc_datetime)
    end

    create table(:task_history) do
      add :task_id, :integer
      add :task_entity, :string
      add :task_entity_id, :integer
      add :task_entity_identifier, :string
      add :task_type, :string
      add :task_status, :integer
      add :task_retry_date, :utc_datetime
      add :message, :text

      timestamps(type: :utc_datetime)
    end

    create table(:schedulers) do
      add :name, :string
      add :cron_expression, :string
      add :status, :integer, default: 0
    end

    # Masterdata: Currencies
    create table(:master_data_currencies) do
      add :sort, :integer, null: false
      add :code, :string, null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:master_data_currencies, [:sort],
             name: :master_data_currencies_sort_index
           )

    create unique_index(:master_data_currencies, [:code],
             name: :master_data_currencies_code_index
           )

    create unique_index(:master_data_currencies, [:name],
             name: :master_data_currencies_name_index
           )

    create unique_index(:master_data_currencies, [:code, :name, :sort],
             name: :master_data_currencies_code_name_sort_index
           )

    # Masterdata: Groups
    create table(:master_data_groups) do
      add :sort, :integer, null: false
      add :code, :string, null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:master_data_groups, [:sort], name: :master_data_groups_sort_index)
    create unique_index(:master_data_groups, [:code], name: :master_data_groups_code_index)
    create unique_index(:master_data_groups, [:name], name: :master_data_groups_name_index)

    create unique_index(:master_data_groups, [:code, :name, :sort],
             name: :master_data_groups_code_name_sort_index
           )
  end
end
