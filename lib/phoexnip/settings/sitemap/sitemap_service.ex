defmodule Phoexnip.SitemapService do
  @moduledoc """
  Service functions for managing `Sitemap` records.

  Provides:

    * `list/0`       – returns all sitemap entries
    * `get/1`        – fetches a sitemap by id, returns `nil` if not found
    * `get!/1`       – fetches a sitemap by id, raises if not found
    * `get_by/1`     – fetches a sitemap by given args, returns `nil` if not found
    * `get_by!/1`    – fetches a sitemap by given args, raises if not found
    * `create/1`     – creates a new sitemap entry
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Sitemap

  @doc """
  Returns all `Sitemap` records.
  """
  @spec list() :: [Sitemap.t()]
  def list do
    Repo.all(Sitemap)
  end

  @doc """
  Retrieves a `Sitemap` by its `id`.

  Returns `nil` if no record is found.
  """
  @spec get(id :: term()) :: Sitemap.t() | nil
  def get(id) do
    Repo.get(Sitemap, id)
  end

  @doc """
  Retrieves a `Sitemap` by its `id`.

  Raises `Ecto.NoResultsError` if no record is found.
  """
  @spec get!(id :: term()) :: Sitemap.t()
  def get!(id), do: Repo.get!(Sitemap, id)

  @doc """
  Retrieves a `Sitemap` matching the given `args`.

  Returns `nil` if no record is found.
  """
  @spec get_by(args :: keyword() | map()) :: Sitemap.t() | nil
  def get_by(args), do: Repo.get_by(Sitemap, args)

  @doc """
  Retrieves a `Sitemap` matching the given `args`.

  Raises `Ecto.NoResultsError` if no record is found.
  """
  @spec get_by!(args :: keyword() | map()) :: Sitemap.t()
  def get_by!(args), do: Repo.get_by!(Sitemap, args)

  @doc """
  Creates a new `Sitemap` with the given attributes.

  Returns `{:ok, sitemap}` on success or `{:error, changeset}` on failure.
  """
  @spec create(attrs :: map()) :: {:ok, Sitemap.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %Sitemap{}
    |> Sitemap.changeset(attrs)
    |> Repo.insert()
  end
end
