defmodule Phoexnip.Mailer do
  @moduledoc """
  Swoosh mailer configuration for the Phoexnip application.

  This module wraps `Swoosh.Mailer` and is configured via the `:phoexnip` OTP app
  (i.e. your SMTP/adapters are defined under `config :phoexnip, Phoexnip.Mailer`).
  """

  use Swoosh.Mailer, otp_app: :phoexnip
end

defmodule Phoexnip.EmailUtils do
  @moduledoc """
  Email delivery utilities for Phoexnip.

  Provides a single `deliver/6` function to send HTML emails with optional CC,
  filesystem attachments, and in-memory binary attachments.

  ## Functions

    * `deliver(recipients, cc, subject, body, attachment_paths \\ [], attachment_binaries \\ [])`
      - `recipients` — a string or list of strings for the “To” header
      - `cc` — a string or list of strings for the “Cc” header
      - `subject` — the email subject
      - `body` — the HTML body content
      - `attachment_paths` — a list of filesystem paths to attach
      - `attachment_binaries` — a list of `{binary, filename, content_type}` tuples

  ## Examples

      iex> Phoexnip.EmailUtils.deliver(
      ...>   "to@example.com",
      ...>   ["cc1@example.com", "cc2@example.com"],
      ...>   "Hello!",
      ...>   "<p>Welcome aboard.</p>",
      ...>   ["/tmp/report.pdf"],
      ...>   [{<<data::binary>>, "notes.txt", "text/plain"}]
      ...> )
      {:ok, %Swoosh.Email{}}

  On failure, returns `{:error, reason}`.
  """
  import Swoosh.Email
  alias Phoexnip.Mailer
  alias Swoosh.Attachment

  @doc """
  Delivers an email to the specified recipient(s) with optional CC, file- and binary attachments.

  ## Parameters

    - `recipients` (string or list of strings)
      One or more To: addresses.

    - `cc` (string or list of strings)
      One or more Cc: addresses.

    - `subject` (string)
      The subject line.

    - `body` (string)
      The HTML body content.

    - `attachment_paths` (list of strings)
      Filesystem paths to attach. Defaults to `[]`.

    - `attachment_binaries` (list of `{binary, filename, content_type}` tuples)
      In-memory blobs to attach. Defaults to `[]`.

  ## Returns

    - `{:ok, email}` on success
    - `{:error, reason}` on failure
  """
  @spec deliver(
          recipients :: String.t() | [String.t()],
          cc :: String.t() | [String.t()],
          subject :: String.t(),
          body :: String.t(),
          attachment_paths :: [String.t()],
          attachment_binaries :: [{binary(), String.t(), String.t()}]
        ) :: {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver(
        recipients,
        cc,
        subject,
        body,
        attachment_paths \\ [],
        attachment_binaries \\ []
      ) do
    {from_name, from_email} =
      Application.get_env(:phoexnip, :mailer_from, {"Phoexnip", "noreply@example.com"})

    email =
      new()
      |> from({from_name, from_email})
      |> subject(subject)
      |> html_body(body)

    # To: header
    email =
      case recipients do
        list when is_list(list) ->
          Enum.reduce(list, email, fn
            addr, acc
            when is_binary(addr) and addr != "" ->
              to(acc, addr)

            _, acc ->
              acc
          end)

        single when is_binary(single) and single != "" ->
          to(email, single)

        _ ->
          # covers "", nil, charlists, etc.
          email
      end

    # Cc: header
    email =
      case cc do
        list when is_list(list) ->
          Enum.reduce(list, email, fn
            addr, acc
            when is_binary(addr) and addr != "" ->
              cc(acc, addr)

            _, acc ->
              acc
          end)

        single when is_binary(single) and single != "" ->
          cc(email, single)

        _ ->
          email
      end

    # Filesystem attachments
    email =
      Enum.reduce(attachment_paths, email, fn path, email ->
        attachment(email, path)
      end)

    # In-memory binary attachments
    email =
      Enum.reduce(attachment_binaries, email, fn {data, filename, content_type}, email ->
        attach_struct =
          Attachment.new({:data, data},
            filename: filename,
            content_type: content_type
          )

        attachment(email, attach_struct)
      end)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
