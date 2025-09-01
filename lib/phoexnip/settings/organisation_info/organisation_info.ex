defmodule Phoexnip.Settings.OrganisationInfo do
  @moduledoc """
  Represents the organisation information settings for Phoexnip.

  This schema holds details such as the organisation name, registration numbers,
  contact information, website, email, currency, and associated addresses.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__, :inserted_at, :updated_at]}

  @typedoc "A `%OrganisationInfo{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          name: String.t() | nil,
          registration_number: String.t() | nil,
          gst_number: String.t() | nil,
          socso_number: String.t() | nil,
          pcb_number: String.t() | nil,
          phone: String.t() | nil,
          fax: String.t() | nil,
          website: String.t() | nil,
          email: String.t() | nil,
          currency: String.t() | nil,
          address: [Phoexnip.Address.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "organisation_info" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    # Organisation name
    field :name, :string
    # Registration number
    field :registration_number, :string
    # GST number
    field :gst_number, :string
    # SOCSO number
    field :socso_number, :string
    # PCB number
    field :pcb_number, :string
    # Primary contact phone
    field :phone, :string
    # Fax number
    field :fax, :string
    # Website URL
    field :website, :string
    # Contact email
    field :email, :string
    # Default currency code
    field :currency, :string

    has_many :address, Phoexnip.Address, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @spec schema_fields() :: [atom()]
  defp schema_fields do
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Returns a changeset for OrganisationInfo based on the given `attrs`.

  Validates the presence of the `:name` field and casts
  all other schema fields. Also casts associated addresses.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(organisation_info, attrs) when is_map(attrs) do
    organisation_info
    |> cast(attrs, schema_fields())
    |> validate_required([:name])
    |> cast_assoc(:address)
  end
end
