defmodule Phoexnip.EctoUtils do
  @moduledoc """
  Macro to allow schema field definitions to use migration-friendly types,
  automatically mapping to Ecto's supported schema types.

  Usage:
      import Ecto.Schema, except: [field: 2], warn: false
      import Phoexnip.EctoUtils, only: [field: 2]
      field :remark, :text
      field :uuid, :uuid
      field :tags, {:array, :text}
      field :payload, :jsonb
  """

  @type_mapping %{
    # strings
    text: :string,
    varchar: :string,
    char: :string,
    citext: :string,

    # identifiers/binary
    uuid: :binary_id,
    bytea: :binary,

    # numbers
    bigint: :integer,
    smallint: :integer,
    int: :integer,
    int4: :integer,
    int8: :integer,
    float4: :float,
    float8: :float,
    double: :float,
    double_precision: :float,
    numeric: :decimal,

    # datetimes/dates
    timestamptz: :utc_datetime,
    timestamp: :naive_datetime,
    naive_datetime: :naive_datetime,
    utc_datetime: :utc_datetime,
    date: :date,
    time: :time,

    # json
    json: :map,
    jsonb: :map
  }

  ### Type mapping support for arrays, eg {:array, :text} -> {:array, :string}
  defp map_type({:array, subtype}) do
    {:array, map_type(subtype)}
  end

  ###
  defp map_type(type) when is_atom(type) do
    Map.get(@type_mapping, type, type)
  end

  defmacro field(name, type, opts \\ []) do
    mapped_type = map_type(type)

    quote do
      Ecto.Schema.field(unquote(name), unquote(mapped_type), unquote(opts) || [])
    end
  end
end
