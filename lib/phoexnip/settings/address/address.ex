defmodule Phoexnip.Address do
  @moduledoc """
  An Ecto schema for storing postal address records.

  Provides:

  - `schema_fields/0` to list only the user‐editable fields
  - `changeset/2` to cast a map of attrs into an `%Address{}` changeset
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           except: [:__meta__, :inserted_at, :updated_at, :organisation_info]}
  schema "address" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :guid, :string
    field :attn, :string
    field :attn2, :string
    field :line1, :string
    field :line2, :string
    field :line3, :string
    field :postcode, :string
    field :city, :string
    field :state, :string
    field :country, :string
    field :category, :string
    field :sequence, :integer
    field :supplier_mco, :string
    belongs_to :organisation_info, Phoexnip.Settings.OrganisationInfo

    timestamps(type: :utc_datetime)
  end

  @typedoc "An `%Address{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          guid: String.t() | nil,
          attn: String.t() | nil,
          attn2: String.t() | nil,
          line1: String.t() | nil,
          line2: String.t() | nil,
          line3: String.t() | nil,
          postcode: String.t() | nil,
          city: String.t() | nil,
          state: String.t() | nil,
          country: String.t() | nil,
          category: String.t() | nil,
          sequence: integer() | nil,
          supplier_mco: String.t() | nil,
          organisation_info_id: integer() | nil,
          organisation_info: Phoexnip.Settings.OrganisationInfo.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defp schema_fields do
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Builds an `%Ecto.Changeset{}` for an `Address` from the given `attrs` map.

  ## Parameters

    - `address` (`%Address{}`): the struct to cast into (new or existing)
    - `attrs` (`map`): the params to cast

  ## Examples

      iex> attrs = %{line1: "123 Main St", city: "Metropolis"}
      iex> Phoexnip.Address.changeset(%Phoexnip.Address{}, attrs)
      #Ecto.Changeset<action: nil, changes: %{city: "Metropolis", line1: "123 Main St"}, errors: [], data: %Phoexnip.Address{…}>

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(address, attrs) when is_map(attrs) do
    address
    |> cast(attrs, schema_fields())
  end
end
