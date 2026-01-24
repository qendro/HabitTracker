defmodule HabitTracker.Workers.PurgeDeletedAccountsJob do
  @moduledoc """
  Oban cron worker that runs daily at 2 AM UTC to permanently purge deleted accounts.

  This job:
  1. Finds accounts deleted more than 30 days ago
  2. Permanently deletes user, habits, and logs
  3. Anonymizes data in analytics (removes from daily_metrics if needed)

  Accounts are soft-deleted immediately when users request deletion,
  then permanently purged after 30 days.
  """

  use Oban.Worker, queue: :cleanup

  import Ecto.Query
  alias HabitTracker.Repo
  alias HabitTracker.Accounts.User
  alias HabitTracker.Tracker.{Habit, HabitLog}

  @purge_after_days 30

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Find users deleted more than 30 days ago
    cutoff_date = DateTime.add(DateTime.utc_now(), -@purge_after_days, :day)

    users_to_purge =
      from(u in User,
        where: not is_nil(u.deleted_at),
        where: u.deleted_at < ^cutoff_date,
        select: u.id
      )
      |> Repo.all()

    # Purge each user
    Enum.each(users_to_purge, &purge_user/1)

    :ok
  end

  defp purge_user(user_id) do
    Repo.transaction(fn ->
      # Delete habit logs
      from(log in HabitLog, where: log.user_id == ^user_id)
      |> Repo.delete_all()

      # Delete habits
      from(h in Habit, where: h.user_id == ^user_id)
      |> Repo.delete_all()

      # Delete reminder settings
      from(rs in HabitTracker.Reminders.ReminderSettings, where: rs.user_id == ^user_id)
      |> Repo.delete_all()

      # Delete user tokens
      from(t in HabitTracker.Accounts.UserToken, where: t.user_id == ^user_id)
      |> Repo.delete_all()

      # Finally, delete the user
      from(u in User, where: u.id == ^user_id)
      |> Repo.delete_all()

      # Note: Analytics anonymization would happen here if we were tracking
      # user-specific data in daily_metrics. Currently, daily_metrics only
      # contains aggregate counts, so no anonymization is needed.
    end)
  end
end
