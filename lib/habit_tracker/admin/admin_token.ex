defmodule HabitTracker.Admin.AdminToken do
  use Ecto.Schema
  import Ecto.Query

  alias HabitTracker.Admin.Admin
  alias HabitTracker.Admin.AdminToken

  @rand_size 32
  @session_validity_in_days 30

  schema "admins_tokens" do
    field :token, :binary
    field :context, :string
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

  defp by_token_and_context_query(token, context) do
    from AdminToken, where: [token: ^token, context: ^context]
  end
end
