defmodule Phoexnip.Settings.ApiKey do
  @moduledoc """
  Ecto schema and changeset functions for managing ApiKey records.

  Each record holds a generated API key, its owner, and validity timestamps.
  Provides:

    * `changeset/2` – for creating or updating `%ApiKey{}` records (casts fields, validates presence, enforces unique `:key`)
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Phoexnip.ServiceUtils

  @typedoc "An `%ApiKey{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          given_to: String.t() | nil,
          key: String.t() | nil,
          valid_until: DateTime.t() | nil,
          refresh_key: String.t() | nil,
          refresh_until: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder, except: [:__meta__, :inserted_at, :updated_at]}
  schema "api_key" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :given_to, :string
    field :key, :string
    field :valid_until, :utc_datetime
    field :refresh_key, :string
    field :refresh_until, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec schema_casts() :: [atom()]
  defp schema_casts do
    # all schema fields except primary key and timestamps
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @doc """
  Builds a changeset for **creating or updating** an `%ApiKey{}`.

  Casts all schema fields, ensures required fields are present, and checks uniqueness of `:key`.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(api_key, attrs) when is_map(attrs) do
    api_key
    |> cast(attrs, schema_casts())
    |> validate_required([:key, :given_to, :valid_until, :refresh_key, :refresh_until])
    |> unique_constraint(:key)
  end

  @doc """
  Generates and persists a new API key pair for the given identifier.

  Creates a random base64-encoded `key` and `refresh_key`, sets
  `valid_until` to 1 day from now and `refresh_until` to 7 days from now
  (UTC), and inserts the record.

  Returns `{:ok, %ApiKey{}}` on success or `{:error, %Ecto.Changeset{}}` on failure.
  """
  @spec generate_api_key(String.t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def generate_api_key(given_to) when is_binary(given_to) do
    api_key = :crypto.strong_rand_bytes(32) |> Base.encode64() |> binary_part(0, 43)
    refresh_key = :crypto.strong_rand_bytes(64) |> Base.encode64() |> binary_part(0, 86)

    utc_now = Timex.now("Etc/UTC")
    valid_until = Timex.shift(utc_now, days: 1)
    refresh_until = Timex.shift(utc_now, days: 7)

    ServiceUtils.create(__MODULE__, %{
      key: api_key,
      given_to: given_to,
      valid_until: valid_until,
      refresh_key: refresh_key,
      refresh_until: refresh_until
    })
  end
end
