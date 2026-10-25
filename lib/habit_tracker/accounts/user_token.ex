defmodule HabitTracker.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query

  schema "users_tokens" do
    field :token, :binary, redact: true
    field :context, :string
    field :sent_to, :string
    field :authenticated_at, :utc_datetime
    belongs_to :user, HabitTracker.Accounts.User
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(32)

    {token,
     %__MODULE__{
       token: token,
       context: "session",
       user_id: user.id,
       authenticated_at: user.authenticated_at || DateTime.utc_now(:second)
     }}
  end

  def verify_session_token_query(token) do
    {:ok,
     from(t in __MODULE__,
       join: u in assoc(t, :user),
       where:
         t.token == ^token and t.context == "session" and t.inserted_at > ago(30, "day") and
           is_nil(u.deleted_at),
       select: {%{u | authenticated_at: t.authenticated_at}, t.inserted_at}
     )}
  end
end
