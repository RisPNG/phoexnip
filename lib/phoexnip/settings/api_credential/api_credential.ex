defmodule Phoexnip.Settings.ApiCredential do
  @moduledoc """
  Ecto schema and changeset functions for managing ApiCredential records.

  Each record stores a `job` identifier and a GCM-encrypted `credential` string.
  Provides:

    * `changeset/2`           – for creating or updating records (enforces presence and uniqueness of `:job`)
    * `decrypt_credential/1` – for decrypting stored credential
  """

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "An `%ApiCredential{}` struct"
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          job: String.t() | nil,
          credential: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defp schema_fields do
    __schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  @derive {Jason.Encoder, except: [:__meta__, :inserted_at, :updated_at]}
  schema "api_credential" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :job, :string
    field :credential, :text

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for **creating** or **updating** an `%ApiCredential{}`.

  Casts `:job` and `:credential`, validates required fields,
  ensures unique `:job`, and encrypts `:credential` if changed.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(creds, attrs) when is_map(attrs) do
    creds
    |> cast(attrs, schema_fields())
    |> validate_required([:job, :credential])
    |> unique_constraint(:job)
    |> maybe_encrypt_credential()
  end

  @doc """
  Decrypts the `:credential` field if it is a binary.

  Returns the struct with decrypted credential on success,
  or the original struct on failure.
  """
  @spec decrypt_credential(t()) :: t()
  def decrypt_credential(%__MODULE__{credential: enc} = struct) when is_binary(enc) do
    case Phoexnip.EncryptionUtils.gcm_decrypt(enc) do
      {:ok, dec} -> %{struct | credential: dec}
      _ -> struct
    end
  end

  def decrypt_credential(struct), do: struct

  @spec maybe_encrypt_credential(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp maybe_encrypt_credential(changeset) do
    case get_change(changeset, :credential) do
      nil ->
        changeset

      plaintext ->
        put_change(changeset, :credential, Phoexnip.EncryptionUtils.gcm_encrypt(plaintext))
    end
  end
end
