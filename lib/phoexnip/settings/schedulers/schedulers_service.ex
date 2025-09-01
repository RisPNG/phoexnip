defmodule Phoexnip.Settings.SchedulersService do
  @moduledoc """
  Service functions for managing `Schedulers` records.

  Provides:

    * `list/0`        – returns all scheduler
    * `list_active/0` – returns all active scheduler (status == 1)
    * `get/1`         – fetches a scheduler by id, returns `nil` if not found
    * `get!/1`        – fetches a scheduler by id, raises if not found
    * `get_by/1`      – fetches a scheduler by given args, returns `nil` if not found
    * `get_by!/1`     – fetches a scheduler by given args, raises if not found
    * `create/1`      – creates a new scheduler
    * `update/2`      – updates an existing scheduler
  """

  import Ecto.Query, warn: false
  alias Phoexnip.Repo
  alias Phoexnip.Settings.Schedulers

  @doc """
  Returns all `Schedulers` records.
  """
  @spec list() :: [Schedulers.t()]
  def list() do
    Repo.all(Schedulers)
  end

  @doc """
  Returns all active `Schedulers` records (where `status == 1`).
  """
  @spec list_active() :: [Schedulers.t()]
  def list_active() do
    Repo.all(from s in Schedulers, where: s.status == 1)
  end

  @doc """
  Retrieves a `Schedulers` by its `id`.

  Returns `nil` if no record is found.
  """
  @spec get(id :: term()) :: Schedulers.t() | nil
  def get(id) do
    Repo.get(Schedulers, id)
  end

  @doc """
  Retrieves a `Schedulers` by its `id`.

  Raises `Ecto.NoResultsError` if no record is found.
  """
  @spec get!(id :: term()) :: Schedulers.t()
  def get!(id), do: Repo.get!(Schedulers, id)

  @doc """
  Retrieves a `Schedulers` matching the given `args`.

  Raises `Ecto.NoResultsError` if no record is found.
  """
  @spec get_by!(args :: keyword() | map()) :: Schedulers.t()
  def get_by!(args), do: Repo.get_by!(Schedulers, args)

  @doc """
  Retrieves a `Schedulers` matching the given `args`.

  Returns `nil` if no record is found.
  """
  @spec get_by(args :: keyword() | map()) :: Schedulers.t() | nil
  def get_by(args), do: Repo.get_by(Schedulers, args)

  @doc """
  Creates a new `Schedulers` with the given attributes.

  Returns `{:ok, scheduler}` on success or `{:error, changeset}` on failure.
  """
  @spec create(attrs :: map()) :: {:ok, Schedulers.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %Schedulers{}
    |> Schedulers.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing `Schedulers` with the given attributes.

  Returns `{:ok, scheduler}` on success or `{:error, changeset}` on failure.
  """
  @spec update(scheduler :: Schedulers.t(), attrs :: map()) ::
          {:ok, Schedulers.t()} | {:error, Ecto.Changeset.t()}
  def update(%Schedulers{} = scheduler, attrs) do
    scheduler
    |> Schedulers.changeset(attrs)
    |> Repo.update()
  end
end
