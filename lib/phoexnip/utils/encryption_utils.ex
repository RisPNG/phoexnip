defmodule Phoexnip.EncryptionUtils do
  @moduledoc """
  Provides encryption and decryption utilities using AES-256-GCM.

  This module reads a Base64‑encoded 256‑bit key from the `ENC_KEY` environment
  variable, decodes it, and uses it to perform AES‑256‑GCM encryption and decryption.
  Each encryption invocation generates a fresh 96‑bit IV, and the output is the
  concatenation of IV, authentication tag, and ciphertext, all Base64‑encoded.

  ## Configuration

    * `ENC_KEY` – must be set to a Base64‑encoded 32‑byte (256‑bit) key.

  ## Functions

    * `gcm_encrypt/1` – Encrypts a plaintext binary and returns a Base64‑encoded token.
    * `gcm_decrypt/1` – Decrypts a token produced by `gcm_encrypt/1`, returning
      `{:ok, plaintext}` or `:error` on failure.

  ## Error Handling

    * Encryption will raise if `ENC_KEY` is missing or invalid Base64, or if
      the crypto operation fails.
    * Decryption returns `:error` if the key is invalid/missing, the token is malformed,
      or authentication fails.

  ## Examples

      iex> System.put_env("ENC_KEY", Base.encode64(:crypto.strong_rand_bytes(32)))
      iex> token = Phoexnip.EncryptionUtils.gcm_encrypt("top secret")
      iex> is_binary(token)
      true

      iex> {:ok, "top secret"} = Phoexnip.EncryptionUtils.gcm_decrypt(token)
      iex> Phoexnip.EncryptionUtils.gcm_decrypt("invalid-data")
      :error
  """

  @doc """
  Encrypts the given `plaintext` using AES-256-GCM with a 256-bit key.

  Reads the base64-encoded key from the `ENC_KEY` environment variable, decodes it,
  and generates a fresh 96-bit IV for each invocation. The output is the IV concatenated
  with the authentication tag and ciphertext, all base64-encoded for safe storage or transport.

  Raises if:
    * `ENC_KEY` is not set or is not valid Base64
    * the underlying crypto operation fails

  ## Examples

      iex> System.put_env("ENC_KEY", Base.encode64(:crypto.strong_rand_bytes(32)))
      iex> token = gcm_encrypt("secret data")
      iex> is_binary(token)
      true
  """
  @spec gcm_encrypt(plaintext :: binary()) :: String.t()
  def gcm_encrypt(plaintext) do
    key = System.get_env("ENC_KEY") |> Base.decode64!()
    # 96-bit IV (recommended for GCM)
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, <<>>, true)

    # Final encrypted payload = IV || TAG || CIPHERTEXT, base64 encoded for storage
    Base.encode64(iv <> tag <> ciphertext)
  end

  @doc """
  Decrypts a Base64-encoded AES-256-GCM payload created by `gcm_encrypt/1`.

  Reads the Base64-encoded key from the `ENC_KEY` environment variable, decodes it,
  and then safely Base64-decodes the `encoded` argument. Expects the binary format:

    IV (12 bytes) || TAG (16 bytes) || CIPHERTEXT

  Uses `:crypto.crypto_one_time_aead/7` to perform decryption.
  Returns `{:ok, plaintext}` on success, or `:error` if any step fails.

  ## Examples

      iex> System.put_env("ENC_KEY", Base.encode64(:crypto.strong_rand_bytes(32)))
      iex> token = gcm_encrypt("top secret")
      iex> {:ok, "top secret"} = gcm_decrypt(token)

      iex> gcm_decrypt("invalid-data")
      :error
  """
  @spec gcm_decrypt(encoded :: binary()) :: {:ok, binary()} | :error
  def gcm_decrypt(encoded) when is_binary(encoded) do
    with key_base64 when is_binary(key_base64) <- System.get_env("ENC_KEY"),
         {:ok, key} <- Base.decode64(key_base64),
         {:ok, decoded} <- safe_base64_decode(encoded),
         true <- byte_size(decoded) >= 28 do
      <<iv::binary-12, tag::binary-16, ciphertext::binary>> = decoded

      try do
        plaintext =
          :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, <<>>, tag, false)

        {:ok, plaintext}
      rescue
        _ -> :error
      end
    else
      _ -> :error
    end
  end

  # Helper to safely decode Base64 without crashing
  defp safe_base64_decode(data) do
    try do
      {:ok, Base.decode64!(data)}
    rescue
      _ -> :error
    end
  end
end
