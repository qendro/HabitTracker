defmodule HabitTracker.Admin do
  @moduledoc """
  The Admin context.
  """

  import Ecto.Query, warn: false

  alias HabitTracker.Admin.Admin
  alias HabitTracker.Admin.AdminToken
  alias HabitTracker.Repo

  @doc """
  Gets an admin by email.
  """
  def get_admin_by_email(email) when is_binary(email) do
    Repo.get_by(Admin, email: email)
  end

  @doc """
  Gets an admin by email and password.
  """
  def get_admin_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    admin = get_admin_by_email(email)
    if Admin.valid_password?(admin, password), do: admin
  end

  @doc """
  Registers a new admin.
  """
  def register_admin(attrs) do
    %Admin{}
    |> Admin.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a changeset for admin registration.
  """
  def change_admin_registration(admin, attrs \\ %{}, opts \\ []) do
    Admin.registration_changeset(admin, attrs, opts)
  end

  @doc """
  Generates a session token for the given admin.
  """
  def generate_admin_session_token(admin) do
    {token, admin_token} = AdminToken.build_session_token(admin)
    Repo.insert!(admin_token)
    token
  end

  @doc """
  Gets the admin by session token.
  """
  def get_admin_by_session_token(token) do
    with {:ok, query} <- AdminToken.verify_session_token_query(token),
         {admin, token_inserted_at} <- Repo.one(query) do
      {admin, token_inserted_at}
    else
      _ -> nil
    end
  end

  @doc """
  Deletes the given session token.
  """
  def delete_admin_session_token(token) do
    Repo.delete_all(from(AdminToken, where: [token: ^token, context: "session"]))
    :ok
  end

  # User Management functions

  alias HabitTracker.Accounts.User
  alias HabitTracker.Accounts.UserToken
  alias HabitTracker.Tracker.{Habit, HabitLog}
  alias HabitTracker.Admin.{DailyMetric, AdminAction}

  @doc """
  Lists all users in the system.

  Returns a list of all non-deleted users, ordered by most recent first.
  """
  def list_all_users do
    from(u in User,
      where: is_nil(u.deleted_at),
      order_by: [desc: u.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Searches for users by email or ID.

  Returns a list of users matching the search query.
  """
  def search_users(query) when is_binary(query) do
    query = String.trim(query)

    cond do
      # Try to parse as integer ID
      match?({_id, ""}, Integer.parse(query)) ->
        {id, _} = Integer.parse(query)

        from(u in User,
          where: u.id == ^id and is_nil(u.deleted_at),
          order_by: [desc: u.inserted_at]
        )
        |> Repo.all()

      # Search by email
      true ->
        search_pattern = "%#{query}%"

        from(u in User,
          where: ilike(u.email, ^search_pattern) and is_nil(u.deleted_at),
          order_by: [desc: u.inserted_at],
          limit: 50
        )
        |> Repo.all()
    end
  end

  @doc """
  Gets a user summary including habit and log counts.
  """
  def get_user_summary(user_id) do
    user = Repo.get(User, user_id)

    if user do
      habit_count =
        from(h in Habit,
          where: h.user_id == ^user_id and is_nil(h.deleted_at),
          select: count(h.id)
        )
        |> Repo.one()

      log_count =
        from(log in HabitLog,
          where: log.user_id == ^user_id,
          select: count(log.id)
        )
        |> Repo.one()

      %{
        user: user,
        habit_count: habit_count,
        log_count: log_count
      }
    else
      nil
    end
  end

  @doc """
  Deactivates a user account.

  This is a soft operation that prevents login but preserves data.
  Logs the action to admin_actions table.
  """
  def deactivate_user(admin, user) do
    with_audit_log(admin, "deactivate_user", user.id, fn ->
      # For now, we'll use deleted_at as a deactivation flag
      # In a more complete implementation, we might add a separate 'active' field
      user
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
      |> Repo.update()
    end)
  end

  @doc """
  Reactivates a previously deactivated user account.

  Logs the action to admin_actions table.
  """
  def reactivate_user(admin, user) do
    with_audit_log(admin, "reactivate_user", user.id, fn ->
      user
      |> Ecto.Changeset.change(deleted_at: nil)
      |> Repo.update()
    end)
  end

  @doc """
  Soft deletes a user account (admin-initiated).

  Logs the action to admin_actions table.
  """
  def admin_delete_user(admin, user) do
    with_audit_log(admin, "delete_user_requested", user.id, fn ->
      user
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
      |> Repo.update()
    end)
  end

  @doc """
  Forces a password reset for a user by invalidating all their tokens
  and sending a password reset email.

  Logs the action to admin_actions table.
  """
  def force_password_reset(admin, user) do
    with_audit_log(admin, "force_password_reset", user.id, fn ->
      # Delete all existing tokens for this user
      Repo.delete_all(from(t in UserToken, where: t.user_id == ^user.id))

      # Generate a new password reset token
      {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
      Repo.insert!(user_token)

      # In a real implementation, we would send an email here
      # For now, we'll just return success with the token
      {:ok, %{user: user, reset_token: encoded_token}}
    end)
  end

  @doc """
  Logs an admin action to start impersonating a user.
  """
  def log_impersonation_start(admin, user_id) do
    log_admin_action(admin.id, "view_as_started", user_id, true, %{})
  end

  @doc """
  Logs an admin action to end impersonating a user.
  """
  def log_impersonation_end(admin, user_id) do
    log_admin_action(admin.id, "view_as_ended", user_id, true, %{})
  end

  @doc """
  Logs an admin action with metadata.

  This is a public function that can be called directly for logging actions.
  """
  def log_admin_action(admin_id, action, target_user_id, success, metadata \\ %{}) do
    %AdminAction{}
    |> AdminAction.changeset(%{
      admin_id: admin_id,
      action: action,
      target_user_id: target_user_id,
      success: success,
      metadata: metadata
    })
    |> Repo.insert()
  end

  @doc """
  Lists admin actions with optional filters.

  Supports filtering by action type, date range, and target user.
  """
  def list_admin_actions(filters \\ %{}) do
    query = from(a in AdminAction, order_by: [desc: a.inserted_at])

    query =
      if action = filters[:action] do
        from(a in query, where: a.action == ^action)
      else
        query
      end

    query =
      if target_user_id = filters[:target_user_id] do
        from(a in query, where: a.target_user_id == ^target_user_id)
      else
        query
      end

    query =
      if start_date = filters[:start_date] do
        from(a in query, where: a.inserted_at >= ^start_date)
      else
        query
      end

    query =
      if end_date = filters[:end_date] do
        from(a in query, where: a.inserted_at <= ^end_date)
      else
        query
      end

    query
    |> Repo.all()
    |> Repo.preload([:admin, :target_user])
  end

  # Private helper for wrapping admin actions with audit logging
  defp with_audit_log(admin, action, target_user_id, func) do
    case func.() do
      {:ok, result} ->
        log_admin_action(admin.id, action, target_user_id, true, %{})
        {:ok, result}

      {:error, changeset} ->
        metadata = %{
          errors:
            Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
              Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
                opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
              end)
            end)
        }

        log_admin_action(admin.id, action, target_user_id, false, metadata)
        {:error, changeset}
    end
  end

  # Metrics functions

  @doc """
  Calculates daily metrics for a given date.

  Returns a map with all system metrics including user counts, activity metrics,
  and habit statistics.
  """
  def calculate_daily_metrics(date) do
    total_users =
      from(u in User, where: is_nil(u.deleted_at), select: count(u.id))
      |> Repo.one()

    new_users_today =
      from(u in User,
        where: fragment("DATE(?)", u.inserted_at) == ^date,
        select: count(u.id)
      )
      |> Repo.one()

    # DAU: users who logged habits today
    dau =
      from(log in HabitLog,
        where: log.local_date == ^date,
        select: count(fragment("DISTINCT ?", log.user_id))
      )
      |> Repo.one()

    # WAU: users who logged habits in past 7 days
    week_ago = Date.add(date, -7)

    wau =
      from(log in HabitLog,
        where: log.local_date >= ^week_ago and log.local_date <= ^date,
        select: count(fragment("DISTINCT ?", log.user_id))
      )
      |> Repo.one()

    # MAU: users who logged habits in past 30 days
    month_ago = Date.add(date, -30)

    mau =
      from(log in HabitLog,
        where: log.local_date >= ^month_ago and log.local_date <= ^date,
        select: count(fragment("DISTINCT ?", log.user_id))
      )
      |> Repo.one()

    total_habits =
      from(h in Habit, where: is_nil(h.deleted_at), select: count(h.id))
      |> Repo.one()

    completions_today =
      from(log in HabitLog,
        where: log.local_date == ^date,
        where: log.status == :complete,
        select: count(log.id)
      )
      |> Repo.one()

    # Average completion rate across all users
    avg_completion_rate = calculate_system_completion_rate(date)

    %{
      metric_date: date,
      total_users: total_users,
      new_users_today: new_users_today,
      dau: dau,
      wau: wau,
      mau: mau,
      total_habits: total_habits,
      completions_today: completions_today,
      avg_completion_rate: avg_completion_rate
    }
  end

  @doc """
  Stores daily metrics in the database.
  """
  def store_daily_metrics(metrics) do
    %DailyMetric{}
    |> DailyMetric.changeset(metrics)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :metric_date)
  end

  @doc """
  Gets the latest system metrics.
  """
  def system_metrics do
    case Repo.one(from(m in DailyMetric, order_by: [desc: m.metric_date], limit: 1)) do
      nil ->
        # If no metrics exist, calculate for today
        today = Date.utc_today()
        metrics = calculate_daily_metrics(today)
        {:ok, _} = store_daily_metrics(metrics)
        metrics

      metric ->
        Map.from_struct(metric)
    end
  end

  defp calculate_system_completion_rate(date) do
    # Get all completed logs for the date
    completed_count =
      from(log in HabitLog,
        where: log.local_date == ^date,
        where: log.status == :complete,
        select: count(log.id)
      )
      |> Repo.one()

    # Get all scheduled occurrences for the date
    # This is a simplified calculation - in reality we'd need to check each habit's schedule
    # For now, we'll use total habits as a proxy
    total_scheduled =
      from(h in Habit,
        where: is_nil(h.deleted_at),
        select: count(h.id)
      )
      |> Repo.one()

    if total_scheduled > 0 do
      Decimal.div(Decimal.new(completed_count), Decimal.new(total_scheduled))
      |> Decimal.round(2)
      |> Decimal.to_float()
    else
      0.0
    end
  end
end
