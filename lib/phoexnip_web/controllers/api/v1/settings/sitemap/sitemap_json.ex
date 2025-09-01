defmodule PhoexnipWeb.SitemapJSON do
  @moduledoc """
  Handles JSON serialization for Sitemap entries in the Phoexnip application.

  This module provides functions to render Sitemap structs as maps suitable for
  JSON encoding in API responses. It exposes:

    * `index/1` – Renders a list of Sitemap entries.

  """

  alias Phoexnip.Sitemap

  @doc """
  Renders a list of sitemap entries as a JSON-serializable map.

  ## Parameters

    - `%{sitemap_list: sitemap_list}`: A map containing the list of `Sitemap` structs under the `:sitemap_list` key.

  ## Returns

    - A map with the `:data` key holding the serialized sitemap entries as a list of maps.

  ## Example

      iex> index(%{sitemap_list: [s1, s2]})
      %{data: [%{code: ..., displayname: ..., …}, %{…}]}
  """
  @spec index(%{sitemap_list: [%Sitemap{}]}) :: %{data: [map()]}
  def index(%{sitemap_list: sitemap_list}) do
    %{data: for(sitemap <- sitemap_list, do: data(sitemap))}
  end

  @doc false
  @spec data(%Sitemap{}) :: map()
  defp data(%Sitemap{} = sitemap) do
    %{
      code: sitemap.code,
      displayname: sitemap.displayname,
      level: sitemap.level,
      description: sitemap.description,
      parent: sitemap.parent,
      url: sitemap.url,
      sequence: sitemap.sequence
    }
  end
end
