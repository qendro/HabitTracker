defmodule HabitTracker.Admin.AdminToken do
  use Ecto.Schema
  import Ecto.Query

  alias HabitTracker.Admin.Admin
  alias HabitTracker.Admin.AdminToken

  @hash_algorithm :sha256
  @rand_size 32
  @session_validity_in_days 30
  @reset_password_validity_in_hours 1

  schema "admins_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :admin, Admin

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Builds a session token for an admin.
  """
  def build_session_token(admin) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %AdminToken{token: token, context: "session", admin_id: admin.id}}
  end

  @doc """
  Builds a token and its hash to be delivered to the admin's email.
  """
  def build_email_token(admin, context) do
    build_hashed_token(admin, context, admin.email)
  end

  defp build_hashed_token(admin, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %AdminToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       admin_id: admin.id
     }}
  end

  @doc """
  Verifies session token and returns the query.
  """
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: admin in assoc(token, :admin),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: {admin, token.inserted_at}

    {:ok, query}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.
  """
  def verify_email_token_query(token, "reset_password") do
    verify_email_token_query(token, "reset_password", reset_validity_in_seconds())
  end

  defp verify_email_token_query(token, context, validity_in_seconds) do
    cutoff = DateTime.add(DateTime.utc_now(:second), -validity_in_seconds, :second)

    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, context),
            join: admin in assoc(token, :admin),
            where: token.inserted_at > ^cutoff,
            where: token.sent_to == admin.email,
            select: admin

        {:ok, query}

      :error ->
        :error
    end
  end

  defp by_token_and_context_query(token, context) do
    from AdminToken, where: [token: ^token, context: ^context]
  end

  defp reset_validity_in_seconds, do: @reset_password_validity_in_hours * 60 * 60
end
