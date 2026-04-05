defmodule Phoexnip.UploadUtils do
  @moduledoc """
  Utilities for working with uploads and file handling (including images).

  This module centralizes shared logic for files and uploads, including:

    * Image helpers (selecting a user/product image URL or default).
    * Saving uploaded files (size, type, old‑file cleanup, UUID filenames).
    * Safely deleting files under the application's static root.

  ## Configuration

    * `@max_file_size` – 8 MB default upload limit.
    * `@allowed_extensions` – `[".jpg", ".jpeg", ".png", ".gif"]` by default.
    * `@static_root` – application’s `priv/static` directory.

  ## Key Functions

    * `image_for/2` – Pick a URL or default based on an object’s `image` or `image_url`.
    * `fetch_image_for_by_object_identifier/2` – Lookup a user/machine/product by ID and return its image URL or default.
    * `save_upload/6` – Enforce size/type, remove old file, generate safe filename, and copy into uploads.
    * `delete_upload/1` – Safely remove an uploaded file under `priv/static`, guarding against path traversal.

  ## Error Handling

    * MIME/type mismatches and size violations return `{:error, reason}`.
    * File read/copy failures return `{:error, term()}`.
    * Deletion outside of `@static_root` or missing files return descriptive errors.

  ## Examples

      iex> Phoexnip.UploadUtils.image_for(%{image: "a.png,b.png"}, "product")
      "a.png"

      iex> Phoexnip.UploadUtils.image_for(nil, "user")
      "/images/default-user.png"

      iex> Phoexnip.UploadUtils.save_upload("tmp/photo.png")
      {:ok, "/uploads/<uuid>.png"}

      iex> Phoexnip.UploadUtils.delete_upload("/uploads/<uuid>.png")
      {:ok, "Image deleted"}
  """

  # List of allowed extensions
  @max_file_size 8 * 1024 * 1024
  @max_probe_bytes 2048
  @allowed_extensions [".jpg", ".jpeg", ".png", ".gif"]
  @safe_path_segment ~r/\A[a-zA-Z0-9_-]+\z/
  @static_root Application.app_dir(:phoexnip, "priv/static") |> Path.expand()
  @upload_root Path.join(@static_root, "uploads") |> Path.expand()

  @doc """
  Returns the appropriate image URL for the given object and type.

  ## Parameters

    * `object` — a map/struct (or `nil`) that may contain:
      - `:image` (a comma-separated string of product image URLs)
      - `:image_url` (a direct URL for user or machine images)
    * `type` — one of `"product"`, `"user"`, or `"machine"`. Defaults to `"user"`.

  ## Behavior

    * If `type` is `"product"`, returns the first URL from `object.image` (splitting on `","`)
      if present and non-empty; otherwise `"/images/default-product.png"`.
    * For other types, returns `object.image_url` if present and non-empty;
      otherwise returns:
        - `"/images/default-user.png"` for `"user"`
        - `"/images/default-machine.png"` for `"machine"`

  ## Returns

    * A `String.t()` containing the chosen image path.
  """
  @spec image_for(nil | Phoexnip.Users.User.t(), String.t()) :: String.t()
  def image_for(object \\ nil, type \\ "user")

  def image_for(%Phoexnip.Users.User{image_url: url}, "user")
      when is_binary(url) and byte_size(url) > 0,
      do: safe_display_image(url, "/images/default-user.png")

  def image_for(_, _), do: "/images/default-user.png"

  @doc """
  Fetches the image URL for a user identified by `object_id`, falling back to a default.
  """
  @spec fetch_image_for_by_object_identifier(
          object_id :: String.t(),
          type :: String.t()
        ) :: String.t()
  def fetch_image_for_by_object_identifier(object_id, type \\ "user") do
    case type do
      "user" ->
        user = Phoexnip.Users.UserService.get_user_by(%{name: object_id})

        if user != nil && user.image_url && String.length(user.image_url) > 0 do
          safe_display_image(user.image_url, "/images/default-user.png")
        else
          "/images/default-user.png"
        end
    end
  end

  # Function to determine the MIME type based on magic numbers
  # PNG
  defp get_mime_type(<<137, 80, 78, 71, _rest::binary>>), do: ".png"
  # JPEG
  defp get_mime_type(<<255, 216, 255, _rest::binary>>), do: ".jpeg"
  # GIF (GIF87a or GIF89a)
  defp get_mime_type(<<71, 73, 70, 56, _rest::binary>>), do: ".gif"
  # WebP
  defp get_mime_type(<<82, 73, 70, 70, _::binary-size(4), 87, 69, 66, 80, _rest::binary>>),
    do: ".webp"

  # BMP
  defp get_mime_type(<<66, 77, _rest::binary>>), do: ".bmp"
  # TIFF (Little-endian)
  defp get_mime_type(<<73, 73, 42, 0, _rest::binary>>), do: ".tiff"
  # TIFF (Big-endian)
  defp get_mime_type(<<77, 77, 0, 42, _rest::binary>>), do: ".tiff"
  # ICO
  defp get_mime_type(<<0, 0, 1, 0, _rest::binary>>), do: ".ico"

  # old BIFF (“.xls”)
  defp get_mime_type(<<0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, _::binary>>),
    do: ".xls"

  # ZIP header (could be xlsx)
  defp get_mime_type(<<0x50, 0x4B, 0x03, 0x04, _::binary>>), do: ".zip"

  # PDF
  defp get_mime_type(<<37, 80, 68, 70, 45, _rest::binary>>), do: ".pdf"

  # Default if no match
  defp get_mime_type(_), do: "unknown"

  @spec detect_mime_type(binary()) :: String.t()
  defp detect_mime_type(binary_data) when is_binary(binary_data) do
    get_mime_type(binary_data)
  end

  @spec validate_mime_type(
          bytes :: binary(),
          allowed_extensions :: [String.t()]
        ) :: {:ok, String.t()} | {:error, String.t()}
  defp validate_mime_type(bytes, allowed_extensions) do
    extension = detect_mime_type(bytes)

    if extension in allowed_extensions do
      {:ok, extension}
    else
      {:error, "Unsupported file type. Allowed types: #{Enum.join(allowed_extensions, ", ")}"}
    end
  end

  @doc """
  Saves a file from a local path into your uploads directory, validating file size and MIME type,
  optionally removing an existing file, and generating a safe filename.

  ## Parameters

    * `source_path` — the file system path (`String.t()`) to the source image.
    * `old_upload_url` — an existing relative file path to remove before saving (defaults to `""`).
    * `max_file_size` — the maximum allowed file size in bytes (defaults to `@max_file_size`).
    * `allowed_extensions` — a list of permitted MIME-based extensions (e.g. `[".png", ".jpg"]`), defaults to `@allowed_extensions`.
    * `path_suffix` — an optional directory suffix under `"/uploads/"` to namespace saved files (defaults to `""`).
    * `file_name` — an optional base name for the new file; if blank or `nil`, a UUID will be generated (defaults to `""`).

  ## Behavior

    1. Checks the file size via `File.stat/1`; if it exceeds `max_file_size`, returns `{:error, _}` immediately.
    2. Reads the first 2048 bytes to validate its MIME type with `validate_mime_type/2`.
    3. If an `old_upload_url` is provided, builds its absolute path under `@static_root`, ensures it lives within that root, and deletes it if present.
    4. Constructs a new filename in the form `"/uploads/" <> path_suffix <> (file_name or UUID) <> extension`.
    5. Ensures the destination directory exists, then copies the source file to the destination.
    6. Returns `{:ok, relative_path}` on success or `{:error, reason}` on failure.

  ## Returns

    * `{:ok, String.t()}` — the new relative path under `@static_root` (e.g. `"/uploads/avatar/123e4567.png"`).
    * `{:error, term()}` — an error tuple if the file is too large, has an unsupported type, or the copy fails.
  """
  @spec save_upload(
          source_path :: String.t(),
          old_upload_url :: String.t(),
          max_file_size :: non_neg_integer(),
          allowed_extensions :: [String.t()],
          path_suffix :: String.t(),
          file_name :: String.t()
        ) :: {:ok, String.t()} | {:error, term()}
  def save_upload(
        source_path,
        old_upload_url \\ "",
        max_file_size \\ @max_file_size,
        allowed_extensions \\ @allowed_extensions,
        path_suffix \\ "",
        # DO NOT USE THE ORIGINAL FILENAME ALWAYS A RANDOM ONE KNOW WHAT YOU ARE DOING
        file_name \\ ""
      ) do
    with {:ok, safe_source_path} <- validate_regular_file_path(source_path),
         {:ok, %File.Stat{size: size}} <- File.stat(safe_source_path) do
      if size <= max_file_size do
        with {:ok, _, mime_blob} <- read_file_head(safe_source_path),
             {:ok, extension} <- validate_mime_type(mime_blob, allowed_extensions),
             :ok <- maybe_delete_existing_upload(old_upload_url),
             {:ok, relative_upload_path, dest_path} <-
               build_upload_destination(path_suffix, file_name, extension),
             :ok <- ensure_parent_directory(dest_path),
             :ok <- copy_file(safe_source_path, dest_path) do
          {:ok, relative_upload_path}
        end
      else
        {:error, "File exceeds #{max_file_size} byte limit (#{size} bytes)"}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes an uploaded file at the given relative path under the application’s static root.

  ## Parameters

    * `image_path` — the relative path (`String.t()`) to the image under `@static_root`.
      - Must be a non-empty binary to attempt deletion.

  ## Behavior

    * If `image_path` is a non-empty binary:
      1. Joins it with `@static_root` and expands to get the absolute `target` path.
      2. If `target` is outside of `@static_root`, returns `{:error, "invalid path"}`.
      3. If no file exists at `target`, returns `{:error, "no image to be deleted"}`.
      4. Otherwise, attempts to remove the file:
         - On success: `{:ok, "Image deleted"}`
         - On failure: `{:error, "could not delete image: inspect(reason)"}`
    * For any other `image_path` value (nil, empty string, non-binary), returns `{:error, "no image to be deleted"}`.

  ## Returns

    * `{:ok, String.t()}` when deletion succeeds.
    * `{:error, String.t()}` when the path is invalid, the file is missing, or deletion fails.
  """
  @spec delete_upload(image_path :: any()) :: {:ok, String.t()} | {:error, String.t()}
  def delete_upload(image_path) when is_binary(image_path) and image_path != "" do
    with {:ok, target} <- validate_managed_upload_path(image_path) do
      cond do
        not File.exists?(target) ->
          {:error, "no image to be deleted"}

        true ->
          case delete_file(target) do
            :ok ->
              {:ok, "File deleted"}

            {:error, reason} ->
              {:error, "could not delete image: #{inspect(reason)}"}
          end
      end
    end
  end

  # all other cases (nil, "", not a binary)
  def delete_upload(_), do: {:error, "no file to be deleted"}

  defp read_file_head(path, bytes \\ @max_probe_bytes) do
    with {:ok, safe_path} <- validate_regular_file_path(path),
         {:ok, device} <- :file.open(String.to_charlist(safe_path), [:read, :binary]) do
      try do
        case :file.read(device, bytes) do
          {:ok, data} -> {:ok, safe_path, data}
          :eof -> {:ok, safe_path, <<>>}
          {:error, reason} -> {:error, reason}
        end
      after
        :ok = :file.close(device)
      end
    end
  end

  defp validate_regular_file_path(path) when is_binary(path) and path != "" do
    expanded_path = Path.expand(path)

    case File.lstat(expanded_path) do
      {:ok, %File.Stat{type: :regular}} ->
        {:ok, expanded_path}

      {:ok, %File.Stat{type: type}} ->
        {:error, "invalid file path: expected a regular file, got #{type}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_regular_file_path(_), do: {:error, "invalid file path"}

  defp maybe_delete_existing_upload(old_upload_url) do
    case maybe_managed_upload_path(old_upload_url) do
      {:ok, target} ->
        if File.exists?(target) do
          delete_file(target)
        else
          :ok
        end

      :skip ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_managed_upload_path(path) when is_binary(path) do
    trimmed_path = String.trim(path)

    cond do
      trimmed_path == "" ->
        :skip

      remote_url?(trimmed_path) ->
        :skip

      not upload_relative_path?(trimmed_path) ->
        :skip

      true ->
        validate_managed_upload_path(trimmed_path)
    end
  end

  defp maybe_managed_upload_path(_), do: :skip

  defp validate_managed_upload_path(path) when is_binary(path) and path != "" do
    cond do
      remote_url?(path) ->
        {:error, "invalid path"}

      not upload_relative_path?(path) ->
        {:error, "invalid path"}

      true ->
        expanded_path = expand_static_relative_path(path)

        if path_within_root?(expanded_path, @upload_root) do
          {:ok, expanded_path}
        else
          {:error, "invalid path"}
        end
    end
  end

  defp validate_managed_upload_path(_), do: {:error, "invalid path"}

  defp build_upload_destination(path_suffix, file_name, extension) do
    with {:ok, normalized_suffix} <- normalize_path_suffix(path_suffix),
         {:ok, sanitized_file_name} <- sanitize_file_name(file_name) do
      upload_segments =
        ["uploads"]
        |> Kernel.++(normalized_suffix)
        |> Kernel.++([sanitized_file_name <> extension])

      relative_upload_path = "/" <> Path.join(upload_segments)
      dest_path = Path.join([@static_root | upload_segments]) |> Path.expand()

      if path_within_root?(dest_path, @upload_root) do
        {:ok, relative_upload_path, dest_path}
      else
        {:error, "invalid upload path"}
      end
    end
  end

  defp normalize_path_suffix(path_suffix) when path_suffix in [nil, ""], do: {:ok, []}

  defp normalize_path_suffix(path_suffix) when is_binary(path_suffix) do
    segments =
      path_suffix
      |> String.split("/", trim: true)
      |> Enum.map(&String.trim/1)

    if Enum.all?(segments, &Regex.match?(@safe_path_segment, &1)) do
      {:ok, segments}
    else
      {:error, "invalid upload path"}
    end
  end

  defp normalize_path_suffix(_), do: {:error, "invalid upload path"}

  defp sanitize_file_name(file_name) when file_name in [nil, ""], do: {:ok, Ecto.UUID.generate()}

  defp sanitize_file_name(file_name) when is_binary(file_name) do
    trimmed_file_name = String.trim(file_name)

    if Regex.match?(@safe_path_segment, trimmed_file_name) do
      {:ok, trimmed_file_name}
    else
      {:error, "invalid file name"}
    end
  end

  defp sanitize_file_name(_), do: {:error, "invalid file name"}

  defp ensure_parent_directory(path) do
    case :filelib.ensure_dir(String.to_charlist(path)) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp copy_file(source_path, dest_path) do
    case :file.copy(String.to_charlist(source_path), String.to_charlist(dest_path)) do
      {:ok, _bytes_copied} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_file(path) do
    :file.delete(String.to_charlist(path))
  end

  defp expand_static_relative_path(path) do
    path
    |> String.trim()
    |> String.trim_leading("/")
    |> Path.expand(@static_root)
  end

  defp upload_relative_path?(path) do
    trimmed_path =
      path
      |> String.trim()
      |> String.trim_leading("/")

    trimmed_path == "uploads" or String.starts_with?(trimmed_path, "uploads/")
  end

  defp remote_url?(path) do
    case URI.parse(path) do
      %URI{scheme: scheme} when is_binary(scheme) and scheme != "" -> true
      _ -> false
    end
  end

  defp safe_display_image(path, fallback)
       when is_binary(path) and is_binary(fallback) do
    trimmed_path = String.trim(path)

    cond do
      trimmed_path == "" ->
        fallback

      remote_url?(trimmed_path) ->
        fallback

      String.starts_with?(trimmed_path, "/uploads/") ->
        trimmed_path

      String.starts_with?(trimmed_path, "/images/") ->
        trimmed_path

      true ->
        fallback
    end
  end

  defp path_within_root?(path, root) do
    expanded_root = Path.expand(root)
    expanded_path = Path.expand(path)

    expanded_path == expanded_root or String.starts_with?(expanded_path, expanded_root <> "/")
  end
end
