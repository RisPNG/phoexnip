defmodule PhoexnipWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """

  use PhoexnipWeb, :controller

  @doc """
  Translates common error tuples into HTTP responses:

    * `{:error, %Ecto.Changeset{}}` → 422 Unprocessable Entity JSON using `PhoexnipWeb.ChangesetJSON`
    * `{:error, :not_found}`         → 404 Not Found HTML or JSON using `PhoexnipWeb.ErrorHTML` / `PhoexnipWeb.ErrorJSON`
  """
  @spec call(Plug.Conn.t(), {:error, Ecto.Changeset.t()} | {:error, :not_found}) :: Plug.Conn.t()
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: PhoexnipWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: PhoexnipWeb.ErrorHTML, json: PhoexnipWeb.ErrorJSON)
    |> render(:"404")
  end
end
