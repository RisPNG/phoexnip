defmodule ApiKeyCache do
  @moduledoc """
  A GenServer-backed, ETS-based cache for storing encrypted API key data with automatic expiration.

  ## Features

    * **In‐memory ETS table** (`:api_key_cache`) for fast lookups with `:read_concurrency` enabled.
    * **AES-GCM encryption** using a 256-bit key generated at startup; each entry is stored as a map containing
      `:iv`, `:tag`, and `:ciphertext`.
    * **Time‐to‐live (TTL)** support on each entry; expired entries are removed automatically on a regular schedule.
    * **Public API**:
      - `start_link/1` to supervise the cache process under a given name.
      - `store/3` to encrypt and insert data with a custom TTL (defaults to 1 hour).
      - `fetch/1` to decrypt and return cached data if it hasn’t expired.
    * **Automatic cleanup** every `@cleanup_interval` (5 minutes) via `handle_info(:cleanup, ...)`.

  ## Internal Callbacks

    * `handle_cast/2` for async storage.
    * `handle_call/3` for synchronous fetches and for retrieving the encryption key.
    * `handle_info/2` to purge expired entries and reschedule the next cleanup.
  """

  use GenServer

  # Set the cleanup interval to 5 minutes (in milliseconds)
  @cleanup_interval :timer.minutes(5)

  @doc """
  Starts the GenServer responsible for caching encrypted API key data.

  ## Parameters

    * `opts` — a map or keyword list of options (currently ignored).

  ## Returns

    * `{:ok, pid}` on successful start and registration under the module name.
    * `{:error, reason}` if the server could not be started.
  """
  @spec start_link(opts :: any()) :: {:ok, pid()} | {:error, any()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Initializes the GenServer state by generating an encryption key, creating the ETS cache, and scheduling cleanup.

  ## Parameters

    * `state` — an initial state map provided to `start_link/1` (may contain other config).

  ## Behavior

    1. Generates a 256-bit AES-GCM encryption key and stores it under `:encryption_key` in the state.
    2. Creates a private ETS table named `:api_key_cache` with `:read_concurrency` enabled.
    3. Calls `schedule_cleanup/0` to schedule periodic removal of expired entries.
    4. Returns `{:ok, new_state}` to start the GenServer with the augmented state.
  """
  @spec init(state :: map()) :: {:ok, map()}
  def init(state) do
    # Generate a random 256-bit encryption key for AES-GCM encryption
    encryption_key = :crypto.strong_rand_bytes(32)
    # Store the encryption key in the state map
    new_state = Map.put(state, :encryption_key, encryption_key)

    # Create an ETS table for caching API keys with private access
    :ets.new(:api_key_cache, [:named_table, :private, read_concurrency: true])

    # Schedule the first cleanup operation
    schedule_cleanup()

    # Return the new state to be used in the GenServer process
    {:ok, new_state}
  end

  @doc """
  Stores and encrypts the given data under `api_key` in the ETS-backed cache with a specified TTL.

  ## Parameters

    * `api_key` — the key under which to store the encrypted data.
    * `data` — any term to be encrypted and cached.
    * `ttl` — time-to-live in milliseconds (defaults to one hour), after which the entry expires.

  ## Behavior

    1. Computes `expiration_time = current_time_ms + ttl`.
    2. Retrieves the encryption key from the GenServer state via `:get_encryption_key`.
    3. Encrypts `data` using `encrypt/2`.
    4. Sends an asynchronous `{:store, api_key, encrypted_data, expiration_time}` cast to the GenServer.

  ## Returns

    * `:ok` once the cast has been issued.
  """
  @spec store(api_key :: any(), data :: any(), ttl :: non_neg_integer()) :: :ok
  def store(api_key, data, ttl \\ :timer.hours(1)) do
    # Calculate the expiration time for the data (current time + TTL)
    expiration_time = :erlang.system_time(:millisecond) + ttl

    # Request the encryption key from the GenServer state
    encryption_key = GenServer.call(__MODULE__, :get_encryption_key)

    # Encrypt the data with the retrieved encryption key
    encrypted_data = encrypt(data, encryption_key)

    # Use asynchronous cast to insert the data into the cache via GenServer
    GenServer.cast(__MODULE__, {:store, api_key, encrypted_data, expiration_time})
  end

  @doc """
  Handles an asynchronous `:store` cast to insert encrypted API key data into the ETS cache.

  ## Parameters

    * `{:store, api_key, encrypted_data, expiration_time}` — a tuple where:
      - `api_key` is the lookup key.
      - `encrypted_data` is the encrypted payload to cache.
      - `expiration_time` is the Unix epoch in milliseconds when the entry should expire.
    * `state` — the current GenServer state (unchanged by this operation).

  ## Behavior

    1. Inserts `{api_key, encrypted_data, expiration_time}` into the ETS table `:api_key_cache`.
    2. Does not send a reply (as per `handle_cast/2` semantics).
    3. Returns `{:noreply, state}` to continue processing.

  ## Returns

    * `{:noreply, state}` — continues the GenServer loop with the given state.
  """
  @spec handle_cast(
          request ::
            {:store, api_key :: any(), encrypted_data :: any(), expiration_time :: integer()},
          state :: any()
        ) :: {:noreply, any()}
  def handle_cast({:store, api_key, encrypted_data, expiration_time}, state) do
    # Insert the api_key, encrypted data, and expiration time into the ETS cache
    :ets.insert(:api_key_cache, {api_key, encrypted_data, expiration_time})
    # Return with no reply
    {:noreply, state}
  end

  @doc """
  Fetches and decrypts the cached value for the given API key via the GenServer.

  ## Parameters

    * `api_key` — the lookup key to fetch from the ETS-backed cache.

  ## Returns

    * `{:ok, decrypted_data}` if the key was found, not expired, and decryption succeeded.
    * `{:error, reason}` if the key was found but decryption failed.
    * `:error` if the key was not found or has expired.
  """
  @spec fetch(api_key :: any()) :: {:ok, any()} | {:error, any()} | :error
  def fetch(api_key) do
    # Make a GenServer call to access the ETS table through the GenServer
    GenServer.call(__MODULE__, {:fetch, api_key})
  end

  @doc """
  Handles synchronous GenServer calls for both fetching cached API key data and retrieving the encryption key.

  ## Supported Requests

    * `{:fetch, api_key}`
      1. Looks up `api_key` in the ETS table `:api_key_cache`.
      2. If found and not expired:
         - Retrieves `{encrypted_data, expiration_time}`.
         - If `expiration_time` is in the future:
           - Decrypts `encrypted_data` using `state[:encryption_key]`.
             - On success returns `{:reply, {:ok, decrypted_data}, state}`.
             - On failure returns `{:reply, {:error, reason}, state}`.
         - If expired:
           - Deletes the ETS entry and returns `{:reply, :error, state}`.
      3. If not found, returns `{:reply, :error, state}`.

    * `:get_encryption_key`
      - Replies immediately with the stored encryption key (`state[:encryption_key]`):
        `{:reply, encryption_key, state}`.

  ## Returns

    * `{:reply, {:ok, any()}, state}` on successful fetch and decryption.
    * `{:reply, {:error, any()}, state}` on fetch decryption failure.
    * `{:reply, :error, state}` if the key is missing or expired.
    * `{:reply, encryption_key, state}` for `:get_encryption_key`.
  """
  @spec handle_call(
          request :: {:fetch, any()} | :get_encryption_key,
          from :: {pid(), any()},
          state :: map()
        ) ::
          {:reply, {:ok, any()} | {:error, any()} | any(), map()}
  def handle_call({:fetch, api_key}, _from, state) do
    case :ets.lookup(:api_key_cache, api_key) do
      # If the key is found, check if it’s still valid
      [{^api_key, encrypted_data, expiration_time}] ->
        if expiration_time > :erlang.system_time(:millisecond) do
          # Retrieve encryption key from the state
          encryption_key = state[:encryption_key]

          # Handle decryption outcomes
          case decrypt(encrypted_data, encryption_key) do
            {:ok, decrypted_data} -> {:reply, {:ok, decrypted_data}, state}
            # Handles both decryption_failed and invalid_data_format
            {:error, reason} -> {:reply, {:error, reason}, state}
          end
        else
          # Delete expired data from the cache
          :ets.delete(:api_key_cache, api_key)
          {:reply, :error, state}
        end

      # If the key is not found, return an error
      _ ->
        {:reply, :error, state}
    end
  end

  def handle_call(:get_encryption_key, _from, state) do
    {:reply, state[:encryption_key], state}
  end

  @doc """
  Handles the `:cleanup` message by removing expired entries from the ETS cache and rescheduling itself.

  ## Parameters

    * `:cleanup` — the message atom that triggers cache maintenance.
    * `state` — the current process state (passed through unchanged).

  ## Behavior

    1. Fetches the current system time in milliseconds.
    2. Deletes all entries in the `:api_key_cache` ETS table whose `expiration_time` (third tuple element) is less than `now`.
    3. Calls `schedule_cleanup/0` to schedule the next cleanup invocation.
    4. Returns `{:noreply, state}` to continue without replying to the caller.

  ## Returns

    * `{:noreply, state}` — the GenServer/LV process continues with its state unmodified.
  """
  @spec handle_info(:cleanup, any()) :: {:noreply, any()}
  def handle_info(:cleanup, state) do
    now = :erlang.system_time(:millisecond)

    # Select and delete entries where expiration_time is past
    :ets.select_delete(:api_key_cache, [{{:"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [true]}])

    # Schedule the next cleanup task
    schedule_cleanup()

    {:noreply, state}
  end

  # Helper function to schedule the cleanup task at regular intervals
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  # Helper function to encrypt data
  defp encrypt(data, encryption_key) do
    # Use Jason to encode the data into JSON
    {:ok, serialized_data} = Jason.encode(data)
    # Generate a 128-bit IV for AES-GCM encryption
    iv = :crypto.strong_rand_bytes(16)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_gcm, encryption_key, iv, serialized_data, <<>>, true)

    %{iv: iv, tag: tag, ciphertext: ciphertext}
  end

  # Helper function to decrypt data
  defp decrypt(%{iv: iv, tag: tag, ciphertext: ciphertext}, encryption_key) do
    case :crypto.crypto_one_time_aead(:aes_gcm, encryption_key, iv, ciphertext, <<>>, tag, false) do
      :error ->
        {:error, :decryption_failed}

      decrypted_data when is_binary(decrypted_data) ->
        case Jason.decode(decrypted_data, keys: :atoms!) do
          {:ok, decoded} ->
            {:ok, decoded}

          _ ->
            {:error, :invalid_data_format}
        end

      _ ->
        {:error, :unexpected_return_value}
    end
  end
end
