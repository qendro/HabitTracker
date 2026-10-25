defmodule HabitTracker.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias HabitTracker.Repo

  alias HabitTracker.Accounts.{User, UserToken}

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.one(from u in User, where: u.email == ^email and is_nil(u.deleted_at))
    if User.valid_password?(user, password) && user.confirmed_at, do: user
  end

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## User settings

  @doc """
  Updates the user timezone.
  """
  def update_user_timezone(user, attrs) do
    user
    |> User.timezone_changeset(attrs)
    |> Repo.update()
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transaction(fn ->
      case Repo.update(changeset) do
        {:ok, user} ->
          tokens_to_expire =
            Repo.all(from t in UserToken, where: t.user_id == ^user.id)

          Repo.delete_all(
            from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id))
          )

          {user, tokens_to_expire}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, {user, tokens_to_expire}} -> {:ok, {user, tokens_to_expire}}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
