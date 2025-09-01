defmodule PhoexnipWeb.MasterDataCurrencyJSON do
  @moduledoc """
  Handles JSON serialization for currency master data in the Phoexnip application.

  This module provides functions to render currency records as maps suitable for JSON encoding:

    * `index/1` – Renders a list of currency.
    * `show/1`  – Renders a single currency.
  """

  alias Phoexnip.Masterdata.Currency

  @doc """
  Renders a list of currency master data entries.

  ## Parameters

    - `%{masterdatas: masterdatas}`: A map containing the list of `Currency` structs under the `:masterdatas` key.

  ## Returns

    - A map with the `:data` key holding the serialized currency as a list of maps.

  ## Example

      iex> index(%{masterdatas: [%Currency{id: 1}, %Currency{id: 2}]})
      %{data: [%{id: 1, sort: ..., code: ..., name: ..., exchange_rate: ...}, %{...}]}
  """
  @spec index(%{masterdatas: [Currency.t()]}) :: %{data: [map()]}
  def index(%{masterdatas: masterdatas}) do
    %{data: for(masterdata <- masterdatas, do: data(masterdata))}
  end

  @doc """
  Renders a single post.
  """
  @spec show(%{masterdata: Currency.t()}) :: %{data: map()}
  def show(%{masterdata: masterdata}) do
    %{data: data(masterdata)}
  end

  @doc false
  @spec data(Currency.t()) :: map()
  defp data(%Currency{} = masterdata) do
    %{
      id: masterdata.id,
      sort: masterdata.sort,
      code: masterdata.code,
      name: masterdata.name,
      exchange_rate: masterdata.exchange_rate
    }
  end
end
