defmodule PhoexnipWeb.UserJSON do
  @moduledoc """
  Handles JSON serialization for User and ApiKey entities in the Phoexnip application.

  This module provides:
    * `index/1`         – Renders a list of users.
    * `show/1`          – Renders a single user.
    * `show_api_key/1`  – Renders a single API key.
  """

  alias Phoexnip.Settings.ApiKey
  alias Phoexnip.Users.User

  @doc """
  Renders a list of users as a JSON‑serializable map.

  ## Parameters

    - `%{users: users}`: Map containing a list of `%User{}` structs under `:users`.

  ## Returns

    - A map with `:data` key holding a list of serialized users.
  """
  @spec index(%{users: [User.t()]}) :: %{data: [map()]}
  def index(%{users: users}) do
    %{data: for(user <- users, do: data(user))}
  end

  @doc """
  Renders a single user as a JSON‑serializable map.

  ## Parameters

    - `%{user: user}`: Map containing a `%User{}` struct under `:user`.

  ## Returns

    - A map with `:data` key holding the serialized user.
  """
  @spec show(%{user: User.t()}) :: %{data: map()}
  def show(%{user: user}) do
    %{data: data(user)}
  end

  @doc """
  Renders a single API key as a JSON‑serializable map.

  ## Parameters

    - `%{api_key: api_key}`: Map containing an `%ApiKey{}` struct under `:api_key`.

  ## Returns

    - A map with `:data` key holding the serialized API key.
  """
  @spec show_api_key(%{api_key: %ApiKey{}}) :: %{data: map()}
  def show_api_key(%{api_key: api_key}) do
    %{data: api_key(api_key)}
  end

  @doc false
  @spec api_key(%ApiKey{}) :: map()
  def api_key(%ApiKey{} = api_key) do
    %{
      given_to: api_key.given_to,
      key: api_key.key,
      valid_until: api_key.valid_until,
      refresh_key: api_key.refresh_key,
      refresh_until: api_key.refresh_until
    }
  end

  @doc false
  @spec data(%User{}) :: map()
  defp data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      group: user.group,
      phone: user.phone,
      image_url: Phoexnip.ImageUtils.image_for(user),
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
end
