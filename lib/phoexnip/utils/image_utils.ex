defmodule Phoexnip.ImageUtils do
  @moduledoc """
  Utilities for resolving, validating, reading, saving, and deleting image files.

  This module centralizes all image‐related logic, including:

    * Choosing the correct URL or default for product, user, and machine images.
    * Fetching an entity’s image by its identifier.
    * Handling attachments on product structs.
    * Detecting MIME types from binary data.
    * Validating file types against a whitelist.
    * Reading raw file bytes (with `.xlsx`‑as‑ZIP support).
    * Validating file paths/extensions without reading contents.
    * Saving uploaded images (size, type, old‑file cleanup, UUID filenames).
    * Safely deleting images under the application's static root.

  ## Configuration

    * `@max_file_size` – 8 MB default upload limit.
    * `@allowed_extensions` – `[".jpg", ".jpeg", ".png", ".gif"]` by default.
    * `@static_root` – application’s `priv/static` directory.

  ## Key Functions

    * `image_for/2` – Pick a URL or default based on an object’s `image` or `image_url`.
    * `fetch_image_for_by_object_identifier/2` – Lookup a user/machine/product by ID and return its image URL or default.
    * `attachment_for/2` – Return a product’s `attachment` or `""`.
    * `detect_mime_type/1` – Inspect the first bytes to map to an extension/mIME.
    * `validate_mime_type/2` – Check that a binary’s detected type is allowed.
    * `read_file/2` – Read and return file bytes only if its type (or ZIP for `.xlsx`) is permitted.
    * `validate_file/2` – Validate a file’s extension or `.xlsx`‑as‑ZIP without loading full contents.
    * `save_image_from_path/6` – Enforce size/type, remove old file, generate safe filename, and copy into uploads.
    * `delete_image/1` – Safely remove an image under `priv/static`, guarding against path traversal.

  ## Error Handling

    * MIME/type mismatches and size violations return `{:error, reason}`.
    * File read/copy failures return `{:error, term()}`.
    * Deletion outside of `@static_root` or missing files return descriptive errors.

  ## Examples

      iex> Phoexnip.ImageUtils.image_for(%{image: "a.png,b.png"}, "product")
      "a.png"

      iex> Phoexnip.ImageUtils.image_for(nil, "user")
      "/images/default-user.png"

      iex> Phoexnip.ImageUtils.validate_mime_type(<<255, 216, 255, 224, ...>>, [".jpg", ".png"])
      {:ok, ".jpeg"}

      iex> Phoexnip.ImageUtils.read_file("priv/static/uploads/data.xlsx", [".xlsx"])
      {:ok, binary()}

      iex> Phoexnip.ImageUtils.save_image_from_path("tmp/photo.png")
      {:ok, "/uploads/<uuid>.png"}

      iex> Phoexnip.ImageUtils.delete_image("/uploads/<uuid>.png")
      {:ok, "Image deleted"}
  """

  # List of allowed extensions
  @max_file_size 8 * 1024 * 1024
  @allowed_extensions [".jpg", ".jpeg", ".png", ".gif"]
  @static_root Path.expand("priv/static")

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

  def image_for(%Phoexnip.Users.User{image_url: url}, "user") when is_binary(url) and byte_size(url) > 0,
    do: url

  def image_for(_, _), do: "/images/default-user.png"


  @doc """
  Fetches the image URL for an entity identified by `object_id`, falling back to a default.

  ## Parameters

    * `object_id` — the identifier for the entity:
      - For `"user"`, this is matched against a `%{name: object_id}` lookup.
      - For `"machine"` and `"product"`, this is matched against `%{number: object_id}`.
    * `type` — one of `"user"`, `"machine"`, or `"product"`. Defaults to `"user"`.

  ## Behavior

    * For `"user"`:
      - Looks up a user via `Phoexnip.Users.UserService.get_user_by!(%{name: object_id})`.
      - Returns `user.image_url` if present and non-empty; otherwise `"/images/default-user.png"`.
    * For `"machine"`:
      - Looks up a machine via `Phoexnip.Manufacturing.MachineService.get_by!(%{number: object_id})`.
      - Returns `machine.image_url` if present and non-empty; otherwise `"/images/default-machine.png"`.
    * For `"product"`:
      - Looks up a product via `Phoexnip.Inventory.ProductService.get_by!(%{number: object_id})`.
      - Returns the first URL from `product.image` if present and non-empty; otherwise `"/images/default-product.png"`.

  ## Returns

    * A `String.t()` with the resolved image path.
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
          user.image_url
        else
          "/images/default-user.png"
        end
    end
  end

  @doc """
  Returns the attachment for a product object, or an empty string if none is present.

  ## Parameters

    * `object` — a map/struct (or `nil`) that may contain an `:attachment` field.
    * `type` — one of `"product"` or any other type. Defaults to `"product"`.

  ## Behavior

    * If `type` is `"product"` and `object.attachment` is neither `nil` nor an empty string, returns `object.attachment`.
    * Otherwise, returns an empty string.

  ## Returns

    * A `String.t()` containing the attachment or `""`.
  """
  @spec attachment_for(
          object :: nil,
          type :: String.t()
        ) :: String.t()
  def attachment_for(object \\ nil, type \\ nil) do
    cond do
      type == "" and object.attachment not in ["", nil] ->
        ""

      true ->
        ""
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

  @doc """
  Detects the MIME type of the given binary data.

  ## Parameters

    * `binary_data` — a binary (`t:binary/0`) containing the raw bytes of a file or payload.

  ## Returns

    * A `String.t()` representing the detected MIME type (e.g. `"image/png"`, `"application/pdf"`).
    * May return `nil` if the type could not be determined (depending on `get_mime_type/1` implementation).
  """
  @spec detect_mime_type(binary()) :: String.t()
  def detect_mime_type(binary_data) when is_binary(binary_data) do
    get_mime_type(binary_data)
  end

  @doc """
  Validates whether the MIME type detected from the given binary data is allowed.

  ## Parameters

    * `bytes` — a `t:binary/0` containing the raw bytes of a file or payload.
    * `allowed_extensions` — a list of MIME type strings (e.g. `[".jpg", ".jpeg", ".png", ".gif"]`) that are permitted. Defaults to `@allowed_extensions`.

  ## Behavior

    1. Calls `detect_mime_type/1` on `bytes` to determine the file’s MIME type.
    2. If the detected type is in `allowed_extensions`, returns `{:ok, extension}`.
    3. Otherwise returns `{:error, "Unsupported file type. Allowed types: …"}`, listing the allowed ones.

  ## Returns

    * `{:ok, extension}` where `extension` is the detected MIME type.
    * `{:error, reason}` with a human-readable message if the type is not allowed.
  """
  @spec validate_mime_type(
          bytes :: binary(),
          allowed_extensions :: [String.t()]
        ) :: {:ok, String.t()} | {:error, String.t()}
  def validate_mime_type(bytes, allowed_extensions \\ @allowed_extensions) do
    extension = detect_mime_type(bytes)

    if extension in allowed_extensions do
      {:ok, extension}
    else
      {:error, "Unsupported file type. Allowed types: #{Enum.join(allowed_extensions, ", ")}"}
    end
  end

  @doc """
  Reads the file at the given `path`, ensuring its MIME type (and, for `.xlsx`, ZIP header) is allowed.

  ## Parameters

    * `path` — a `String.t()` path to the file to read.
    * `allowed_extensions` — a list of allowed file extensions (e.g. `[".xlsx", ".xls"]`).
      - If `".xlsx"` is included, ZIP detection is also enabled.

  ## Behavior

    1. If `".xlsx"` is in `allowed_extensions`, adds `".zip"` to the list so ZIP headers can be detected.
    2. Reads the first 2048 bytes of the file to detect its MIME type via `validate_mime_type/2`.
    3. If detection returns `{:ok, ext}`:
       - If `ext == ".zip"` and `".xlsx"` is allowed, returns the full file contents.
       - If `ext` is in `allowed_extensions`, returns the full file contents.
       - Otherwise, returns an error tuple noting unsupported type.
    4. If detection returns `{:error, reason}`, returns that error.

  ## Returns

    * `{:ok, binary()}` with the full file contents on success.
    * `{:error, String.t()}` if the MIME type (or ZIP header) is not supported.
  """
  @spec read_file(
          path :: String.t(),
          allowed_extensions :: [String.t()]
        ) :: {:ok, binary()} | {:error, String.t()}
  def read_file(path, allowed_extensions \\ [".xlsx", ".xls"]) do
    # we need to do this or the validate_mime_type will not return with the .zip for us to check further
    allowed_extensions =
      if ".xlsx" in allowed_extensions do
        [".zip" | allowed_extensions] |> Enum.uniq()
      else
        allowed_extensions
      end

    head =
      File.stream!(path, 2048)
      |> Enum.to_list()
      |> IO.iodata_to_binary()

    case validate_mime_type(head, allowed_extensions) do
      {:ok, ext} ->
        cond do
          # 1) ZIP header ⇒ only valid if we allow .xlsx
          ext == ".zip" and ".xlsx" in allowed_extensions ->
            IO.inspect(label: "check for xlsx")
            {:ok, File.read!(path)}

          # 2) any other string ext ⇒ must be in allowed_extensions
          ext in allowed_extensions ->
            {:ok, File.read!(path)}

          # 3) got an ext but it isn’t one we allow
          true ->
            {:error,
             "Unsupported file type. Allowed types: #{Enum.join(allowed_extensions, ", ")}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates that the file at `path` has an allowed MIME type (or ZIP header for `.xlsx`) and returns the path.

  ## Parameters

    * `path` — the file system path (`String.t()`) to validate.
    * `allowed_extensions` — a list of allowed extensions (e.g. `[".xlsx", ".xls"]`).
      - If `".xlsx"` is included, ZIP detection is enabled by also allowing `".zip"`.

  ## Behavior

    1. If `".xlsx"` is in `allowed_extensions`, adds `".zip"` to the list so ZIP headers are recognized.
    2. Reads the first 2048 bytes of the file and calls `validate_mime_type/2` on them.
    3. If the detected extension is:
       - `".zip"` and `".xlsx"` is allowed, returns `{:ok, path}`.
       - In `allowed_extensions`, returns `{:ok, path}`.
       - Otherwise, returns `{:error, reason}` noting supported types.
    4. If MIME validation fails, returns `{:error, reason}`.

  ## Returns

    * `{:ok, path}` on success.
    * `{:error, message}` if the file’s type is unsupported.
  """
  @spec validate_file(
          path :: String.t(),
          allowed_extensions :: [String.t()]
        ) :: {:ok, String.t()} | {:error, String.t()}
  def validate_file(path, allowed_extensions \\ [".xlsx", ".xls"]) do
    # we need to do this or the validate_mime_type will not return with the .zip for us to check further
    allowed_extensions =
      if ".xlsx" in allowed_extensions do
        [".zip" | allowed_extensions] |> Enum.uniq()
      else
        allowed_extensions
      end

    head =
      File.stream!(path, 2048)
      |> Enum.to_list()
      |> IO.iodata_to_binary()

    case validate_mime_type(head, allowed_extensions) do
      {:ok, ext} ->
        cond do
          # 1) ZIP header ⇒ only valid if we allow .xlsx
          ext == ".zip" and ".xlsx" in allowed_extensions ->
            IO.inspect(label: "check for xlsx")
            {:ok, path}

          # 2) any other string ext ⇒ must be in allowed_extensions
          ext in allowed_extensions ->
            {:ok, path}

          # 3) got an ext but it isn’t one we allow
          true ->
            {:error,
             "Unsupported file type. Allowed types: #{Enum.join(allowed_extensions, ", ")}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Saves an image from a local path into your uploads directory, validating file size and MIME type,
  optionally removing an existing image, and generating a safe filename.

  ## Parameters

    * `source_path` — the file system path (`String.t()`) to the source image.
    * `old_image_url` — an existing relative image path to remove before saving (defaults to `""`).
    * `max_file_size` — the maximum allowed file size in bytes (defaults to `@max_file_size`).
    * `allowed_extensions` — a list of permitted MIME-based extensions (e.g. `[".png", ".jpg"]`), defaults to `@allowed_extensions`.
    * `path_suffix` — an optional directory suffix under `"/uploads/"` to namespace saved files (defaults to `""`).
    * `file_name` — an optional base name for the new file; if blank or `nil`, a UUID will be generated (defaults to `""`).

  ## Behavior

    1. Checks the file size via `File.stat/1`; if it exceeds `max_file_size`, returns `{:error, _}` immediately.
    2. Reads the first 2048 bytes to validate its MIME type with `validate_mime_type/2`.
    3. If an `old_image_url` is provided, builds its absolute path under `@static_root`, ensures it lives within that root, and deletes it if present.
    4. Constructs a new filename in the form `"/uploads/" <> path_suffix <> (file_name or UUID) <> extension`.
    5. Ensures the destination directory exists, then copies the source file to the destination.
    6. Returns `{:ok, relative_path}` on success or `{:error, reason}` on failure.

  ## Returns

    * `{:ok, String.t()}` — the new relative path under `@static_root` (e.g. `"/uploads/avatar/123e4567.png"`).
    * `{:error, term()}` — an error tuple if the file is too large, has an unsupported type, or the copy fails.
  """
  @spec save_image_from_path(
          source_path :: String.t(),
          old_image_url :: String.t(),
          max_file_size :: non_neg_integer(),
          allowed_extensions :: [String.t()],
          path_suffix :: String.t(),
          file_name :: String.t()
        ) :: {:ok, String.t()} | {:error, term()}
  def save_image_from_path(
        source_path,
        old_image_url \\ "",
        max_file_size \\ @max_file_size,
        allowed_extensions \\ @allowed_extensions,
        path_suffix \\ "",
        # DO NOT USE THE ORIGINAL FILENAME ALWAYS A RANDOM ONE KNOW WHAT YOU ARE DOING
        file_name \\ ""
      ) do
    # First check its size, if to big early return
    case File.stat(source_path) do
      {:ok, %File.Stat{size: size}} when size <= max_file_size ->
        # Read only the first chunk for MIME validation
        mime_blob =
          File.stream!(source_path, 2048)
          |> Enum.to_list()
          |> IO.iodata_to_binary()

        case Phoexnip.ImageUtils.validate_mime_type(mime_blob, allowed_extensions) do
          {:ok, extention} ->
            if old_image_url && old_image_url != "" do
              target =
                @static_root
                |> Path.join(old_image_url)
                |> Path.expand()

              if String.starts_with?(target, @static_root) and File.exists?(target) do
                File.rm!(target)
              end
            end

            # Generate a UUID-based filename + extension
            filename =
              "/uploads/" <>
                path_suffix <>
                if file_name in [nil, ""] do
                  Ecto.UUID.generate()
                else
                  file_name
                end <> extention

            dest_path = Path.join(@static_root, filename)
            File.mkdir_p!(Path.dirname(dest_path))

            case File.cp(source_path, dest_path) do
              :ok -> {:ok, filename}
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %File.Stat{size: size}} ->
        {:error, "Image exceeds #{max_file_size} byte limit (#{size} bytes)"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes an image file at the given relative path under the application’s static root.

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
  @spec delete_image(image_path :: any()) :: {:ok, String.t()} | {:error, String.t()}
  def delete_image(image_path) when is_binary(image_path) and image_path != "" do
    target =
      @static_root
      |> Path.join(image_path)
      |> Path.expand()

    cond do
      not String.starts_with?(target, @static_root) ->
        # trying to delete outside of priv/static
        {:error, "invalid path"}

      not File.exists?(target) ->
        {:error, "no image to be deleted"}

      true ->
        # attempt the deletion and wrap any error
        case File.rm(target) do
          :ok ->
            {:ok, "Image deleted"}

          {:error, reason} ->
            {:error, "could not delete image: #{inspect(reason)}"}
        end
    end
  end

  # all other cases (nil, "", not a binary)
  def delete_image(_), do: {:error, "no image to be deleted"}
end
