defmodule Phoexnip.Users.UserToken do
  @moduledoc """
  Ecto schema for a user token record.

  Each `%UserToken{}` represents various tokens for user actions
  such as sessions, email confirmations, and password resets.

  Provides:
    * `build_session_token/1` – creates a session token.
    * `verify_session_token_query/1` – verifies a session token.
    * `build_email_token/2` – creates a hashed email token.
    * `verify_email_token_query/2` – verifies an email token.
    * `verify_change_email_token_query/2` – verifies an email change token.
  """

  use Ecto.Schema
  import Ecto.Query

  alias Phoexnip.Users.UserToken

  @typedoc """
  A `%UserToken{}` struct.
  """
  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          token: binary() | nil,
          context: String.t() | nil,
          sent_to: String.t() | nil,
          user_id: integer() | nil,
          inserted_at: DateTime.t() | nil
        }

  @hash_algorithm :sha256
  @rand_size 32

  @reset_password_validity_in_days 1
  @confirm_validity_in_days 7
  @change_email_validity_in_days 7
  @session_validity_in_days 60

  schema "user_token" do
    import Ecto.Schema, except: [field: 2], warn: false
    import Phoexnip.EctoUtils, only: [field: 2]
    field :token, :binary
    field :context, :string
    field :sent_to, :string

    belongs_to :user, Phoexnip.Users.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Builds a session token for a user.
  """
  @spec build_session_token(struct()) :: {binary(), t()}
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %UserToken{token: token, context: "session", user_id: user.id}}
  end

  @doc """
  Verifies a session token and returns a query for retrieving the user.
  """
  @spec verify_session_token_query(binary()) :: {:ok, Ecto.Query.t()}
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  @doc """
  Builds an email token with a specific context for a user.
  """
  @spec build_email_token(struct(), String.t()) :: {String.t(), t()}
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  @spec build_hashed_token(struct(), String.t(), String.t()) :: {String.t(), t()}
  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  @doc """
  Verifies an email token for a given context.
  """
  @spec verify_email_token_query(String.t(), String.t()) :: {:ok, Ecto.Query.t()} | :error
  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        days = days_for_context(context)

        query =
          from token in by_token_and_context_query(hashed_token, context),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  @spec days_for_context(String.t()) :: integer()
  defp days_for_context("confirm"), do: @confirm_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days

  @doc """
  Verifies a token for changing the user's email.
  """
  @spec verify_change_email_token_query(String.t(), String.t()) :: {:ok, Ecto.Query.t()} | :error
  def verify_change_email_token_query(token, "change:" <> _ = context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  @spec by_token_and_context_query(binary(), String.t()) :: Ecto.Query.t()
  def by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end

  @spec by_user_and_contexts_query(struct(), :all | [String.t()]) :: Ecto.Query.t()
  def by_user_and_contexts_query(user, :all) do
    from t in UserToken, where: t.user_id == ^user.id
  end

  def by_user_and_contexts_query(user, [_ | _] = contexts) do
    from t in UserToken, where: t.user_id == ^user.id and t.context in ^contexts
  end
end
