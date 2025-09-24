defmodule PhoexnipWeb.SitemapController do
  @moduledoc """
  Handles HTTP API endpoints for the application sitemap.

  This controller provides actions to:
    - retrieve the full sitemap (`index/2`)
    - supply Swagger schema definitions for sitemap elements (`swagger_definitions/0`)

  All actions return JSON responses for use in API clients.
  """

  use PhoexnipWeb, :controller
  use PhoenixSwagger

  alias Phoexnip.{ServiceUtils, Sitemap}

  @doc """
  Retrieves the full sitemap structure.

  ## Parameters

    - conn: the connection struct.
    - _params: unused request parameters.

  ## Returns

    - Updated connection with JSON response containing the sitemap list.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    sitemap_list = ServiceUtils.list(Sitemap)
    render(conn, :index, sitemap_list: sitemap_list)
  end

  @doc """
  Returns the Swagger schema definitions for sitemap objects.

  ## Returns

    - A map of Swagger schema definitions, keyed by schema name.
  """
  @spec swagger_definitions() :: map()
  def swagger_definitions do
    %{
      Sitemap:
        swagger_schema do
          title("Sitemap")

          description(
            "A sitemap structure representing different elements with hierarchical levels."
          )

          properties do
            code(:string, "Unique code for the sitemap", required: true)
            displayname(:string, "Display name for the sitemap", required: true)
            level(:integer, "Level of the sitemap in the hierarchy", required: true)
            description(:string, "Description of the sitemap element", required: false)
            parent(:string, "Parent element code", required: false)
            url(:string, "URL for the sitemap element", required: true)
            sequence(:integer, "Sequence number for ordering", required: true)
          end
        end
    }
  end

  @doc false
  swagger_path :index do
    get("/api/v1/sitemap")
    summary("Get Sitemap")
    description("Get the full sitemap")
    produces("application/json")
    security([%{"api_key" => []}])

    response(200, "OK", Schema.ref(:Sitemap))
    response(401, "Not Authorized")
  end
end
