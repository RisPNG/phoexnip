defmodule PhoexnipWeb.OrganisationInformationJSON do
  @moduledoc """
  Handles JSON serialization for Organisation Information in the Phoexnip application.

  This module provides functions to render OrganisationInfo data as maps suitable for
  JSON encoding in API responses. It exposes:

    - `index/1`: Renders the organisation information.
  """

  alias Phoexnip.Settings.OrganisationInfo

  @doc """
  Renders the organisation information as a JSON-serializable map.

  ## Parameters

    - `%{organisation_info: organisation_info}`: A map containing a `OrganisationInfo` struct under the `:organisation_info` key.

  ## Returns

    - A map with the `:data` key holding the serialized organisation information.
  """
  @spec index(%{organisation_info: OrganisationInfo.t()}) :: %{data: map()}
  def index(%{organisation_info: organisation_info}) do
    %{data: data(organisation_info)}
  end

  @doc false
  @spec data(OrganisationInfo.t()) :: map()
  defp data(%OrganisationInfo{} = organisation_info) do
    %{
      id: organisation_info.id,
      name: organisation_info.name,
      registration_number: organisation_info.registration_number,
      gst_number: organisation_info.gst_number,
      socso_number: organisation_info.socso_number,
      pcb_number: organisation_info.pcb_number,
      phone: organisation_info.phone,
      fax: organisation_info.fax,
      website: organisation_info.website,
      email: organisation_info.email,
      currency: organisation_info.currency,
      address: Enum.map(organisation_info.address || [], &address_data/1),
      inserted_at: organisation_info.inserted_at,
      updated_at: organisation_info.updated_at
    }
  end

  @doc false
  @spec address_data(struct()) :: map()
  defp address_data(address) do
    %{
      id: address.id,
      guid: address.guid,
      attn: address.attn,
      line1: address.line1,
      line2: address.line2,
      line3: address.line3,
      postcode: address.postcode,
      city: address.city,
      state: address.state,
      country: address.country,
      category: address.category,
      sequence: address.sequence,
      inserted_at: address.inserted_at,
      updated_at: address.updated_at
    }
  end
end
