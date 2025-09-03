defmodule PhoexnipWeb.MasterDataGroupsJSON do
  @moduledoc """
  Handles JSON serialization for Group master data in the Phoexnip application.

  This module provides functions to render Group master data as maps suitable for
  JSON encoding in API responses. It exposes:

    - `index/1`: Renders a list of group entries.
    - `show/1`: Renders a single group entry.
  """

  alias Phoexnip.Masterdata.Groups

  @doc """
  Renders a list of groups as a JSON-serializable map.

  ## Parameters

    - `%{masterdatas: masterdatas}`: A map containing the list of `Groups` structs under the `:masterdatas` key.

  ## Returns

    - A map with the `:data` key holding the serialized groups as a list of maps.

  ## Example

      iex> index(%{masterdatas: [dept1, dept2]})
      %{data: [%{id: ..., sort: ..., code: ..., name: ...}, ...]}
  """
  @spec index(%{masterdatas: [Groups.t()]}) :: %{data: [map()]}
  def index(%{masterdatas: masterdatas}) do
    %{data: for(masterdata <- masterdatas, do: data(masterdata))}
  end

  @doc """
  Renders a single group as a JSON-serializable map.

  ## Parameters

    - `%{masterdata: masterdata}`: A map containing a `Groups` struct under the `:masterdata` key.

  ## Returns

    - A map with the `:data` key holding the serialized group as a map.

  ## Example

      iex> show(%{masterdata: dept})
      %{data: %{id: ..., sort: ..., code: ..., name: ...}}
  """
  @spec show(%{masterdata: Groups.t()}) :: %{data: map()}
  def show(%{masterdata: masterdata}) do
    %{data: data(masterdata)}
  end

  @doc false
  @spec data(Groups.t()) :: map()
  defp data(%Groups{} = masterdata) do
    %{
      id: masterdata.id,
      sort: masterdata.sort,
      code: masterdata.code,
      name: masterdata.name
    }
  end
end
