defmodule Phoexnip.Schema do
  @moduledoc """
  Wrapper around `Ecto.Schema` that enables using migration-friendly field
  types in schemas while keeping the familiar `field :name, :type` signature.

  Use in place of `use Ecto.Schema`:

      use Phoexnip.Schema

  Then inside your `schema` / `embedded_schema` blocks you can write:

      field :email, :citext
      field :tags, {:array, :text}
      field :payload, :jsonb

  The macro maps those to Ecto-supported types via `Phoexnip.EctoUtils`
  without any import conflicts with `Ecto.Schema.field/2,3`.
  """

  defmacro __using__(_opts) do
    quote do
      # Replicate Ecto.Schema.__using__/1 except we do NOT import
      # Ecto.Schema.schema/2 or embedded_schema/1 to avoid conflicts.
      Module.register_attribute(__MODULE__, :ecto_primary_keys, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_virtual_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_query_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_field_sources, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_assocs, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_embeds, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_raw, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_autogenerate, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_autoupdate, accumulate: true)
      Module.register_attribute(__MODULE__, :ecto_redact_fields, accumulate: true)

      import Phoexnip.Schema, only: [schema: 2, embedded_schema: 1]
    end
  end

  defmacro schema(source, do: block) do
    quote do
      Ecto.Schema.schema unquote(source) do
        # Re-import Ecto.Schema without its field macro to avoid conflicts
        import Ecto.Schema, except: [field: 2, field: 3]
        # Bring in our mapped field macro with the same signature
        import Phoexnip.EctoUtils, only: [field: 2, field: 3]

        unquote(block)
      end
    end
  end

  defmacro embedded_schema(do: block) do
    quote do
      Ecto.Schema.embedded_schema do
        import Ecto.Schema, except: [field: 2, field: 3]
        import Phoexnip.EctoUtils, only: [field: 2, field: 3]

        unquote(block)
      end
    end
  end
end
