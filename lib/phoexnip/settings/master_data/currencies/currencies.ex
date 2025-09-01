defmodule Phoexnip.Masterdata.Currencies do
  @moduledoc """
  Ecto schema and changeset functions for managing Currencies master data records.

  Fields include:
    * `:sort`          – integer sort order (must be unique)
    * `:code`          – string code (must be unique)
    * `:name`          – string name (must be unique)
    * `:exchange_rate` – decimal exchange rate value (optional)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "A `%Currencies{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          sort: integer() | nil,
          code: String.t() | nil,
          name: String.t() | nil,
          exchange_rate: Decimal.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder, except: [:__meta__, :inserted_at, :updated_at]}
  schema "master_data_currencies" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :sort, :integer
    field :code, :string
    field :name, :string
    field :exchange_rate, :decimal

    timestamps(type: :utc_datetime)
  end

  @spec schema_casts() :: [atom()]
  defp schema_casts do
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Builds a changeset for **creating** a new `%Currencies{}`.

  Casts all schema fields, validates required fields (`:sort`, `:code`, `:name`),
  and checks uniqueness of those fields and their combination.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(currencies, attrs) when is_map(attrs) do
    currencies
    |> cast(attrs, schema_casts())
    |> validate_required([:sort, :code, :name])
    |> unsafe_validate_unique(:sort, Phoexnip.Repo, message: "Sort must be unique")
    |> unsafe_validate_unique(:code, Phoexnip.Repo, message: "Code must be unique")
    |> unsafe_validate_unique(:name, Phoexnip.Repo, message: "Name must be unique")
    |> unsafe_validate_unique([:code, :name, :sort], Phoexnip.Repo,
      message: "Combination of code, name, and sort must be unique"
    )
    |> unique_constraint(:sort, name: :master_data_currencies_sort_index)
    |> unique_constraint(:code, name: :master_data_currencies_code_index)
    |> unique_constraint(:name, name: :master_data_currencies_name_index)
    |> unique_constraint([:code, :name, :sort], name: :master_data_currencies_code_name_sort_index)
  end

  @doc """
  Builds a changeset for **updating** an existing `%Currencies{}`.

  Casts all schema fields, validates required fields, and relies on
  database constraints for uniqueness.
  """
  @spec changeset_update(t(), map()) :: Ecto.Changeset.t()
  def changeset_update(currencies, attrs) when is_map(attrs) do
    currencies
    |> cast(attrs, schema_casts())
    |> validate_required([:sort, :code, :name])
    |> unique_constraint(:sort, name: :master_data_currencies_sort_index)
    |> unique_constraint(:code, name: :master_data_currencies_code_index)
    |> unique_constraint(:name, name: :master_data_currencies_name_index)
    |> unique_constraint([:code, :name, :sort], name: :master_data_currencies_code_name_sort_index)
  end
end
