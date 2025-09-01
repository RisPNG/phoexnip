defmodule PhoexnipWeb.ChangesetJSON do
  @moduledoc """
  Handles conversion of Ecto.Changeset errors into JSON-serializable maps.

  This module provides:

    * `error/1` – Renders a changeset's errors into a map under the `:errors` key.
  """

  @doc """
  Renders changeset errors as a JSON-serializable map.

  ## Parameters

    - `%{changeset: changeset}`: A map containing an `Ecto.Changeset` struct under the `:changeset` key.

  ## Returns

    - A map with the `:errors` key holding the translated error messages.
  """
  @spec error(%{changeset: Ecto.Changeset.t()}) :: %{errors: map()}
  def error(%{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  @doc false
  @spec translate_error({String.t(), keyword()}) :: String.t()
  defp translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(PhoexnipWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(PhoexnipWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
