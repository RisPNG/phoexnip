defmodule Phoexnip.Users.UserNotifier do
  @moduledoc """
  Sends password reset instructions via email to users.

  Composes an HTML email containing a reset link and dispatches it using
  `Phoexnip.EmailUtils.deliver/6`. The email informs the user of the password
  reset request and provides a secure URL to reset their password.
  """

  @doc """
  Composes and delivers a password reset email to the given user.

  ## Parameters

    - `user` (`%{email: String.t()}` or struct)
      A map or struct containing at least an `:email` key for the recipient.

    - `url` (`String.t()`)
      The password reset URL to be included in the email body.

  ## Returns

    - `{:ok, Swoosh.Email.t()}` on successful delivery
    - `{:error, any()}` on failure
  """
  @spec deliver_reset_password_instructions(%{email: String.t()} | struct(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, any()}
  def deliver_reset_password_instructions(user, url) do
    Phoexnip.EmailUtils.deliver(
      user.email,
      "",
      "Reset password instructions",
      """
      <html>
      <body style="font-family: Arial, sans-serif; font-size: 16px; color: black; background:#c0c0c0; padding:20px; width: 100%; margin: 0;">

        <table align="center" width="600" style="border-collapse: collapse; margin: 0 auto; background: #fdfffc; border: 1px solid orange; border-radius: 4px; padding: 20px;">
          <tr>
            <td align="center" style="padding: 10px 20px;">
              <h1 style="font-size: 24px; font-weight: bold; margin: 0; text-align: center;">Password Reset</h1>
            </td>
          </tr>
          <tr>
            <td style="padding: 10px 20px; text-align: center;">
              <p>Someone requested that the password be reset for the following account:</p>
              <p>Your email: <strong>#{user.email}</strong></p>
              <p>To reset your password, visit the following address:</p>
              <p><a href="#{url}" style="color: #1a73e8; text-decoration: none;">#{url}</a></p>
            </td>
          </tr>
          <tr>
            <td style="padding: 10px 20px; text-align: center;">
              <p>If this was not you, please take action to secure your account.</p>
            </td>
          </tr>
        </table>

      </body>
      </html>
      """
    )
  end
end
