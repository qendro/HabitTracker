defmodule HabitTracker.Workers.ScheduleRemindersJob do
  @moduledoc """
  Oban cron worker that runs hourly to schedule reminder emails for users.

  This job:
  1. Finds all users with reminders enabled
  2. Computes each user's current local date from their timezone
  3. Determines the next send time based on user's time_of_day preference
  4. Converts send time to UTC for job scheduling
  5. Enqueues ReminderEmailJob for each user with correct date

  The job ensures timezone-aware scheduling so users receive reminders
  at their configured local time, not UTC time.
  """

  use Oban.Worker, queue: :default

  import Ecto.Query
  alias HabitTracker.Repo
  alias HabitTracker.Reminders.ReminderSettings
  alias HabitTracker.Workers.ReminderEmailJob

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Get current UTC time
    now_utc = DateTime.utc_now()

    # Find all users with reminders enabled
    settings =
      from(s in ReminderSettings,
        where: s.enabled == true,
        preload: [:user]
      )
      |> Repo.all()

    # Schedule reminder for each user
    Enum.each(settings, fn setting ->
      schedule_reminder_for_user(setting, now_utc)
    end)

    :ok
  end

  defp schedule_reminder_for_user(setting, now_utc) do
    user = setting.user
    timezone = user.timezone

    # Get user's current local datetime
    now_local = DateTime.shift_zone!(now_utc, timezone)

    # Get the configured time of day for reminders
    reminder_time = setting.time_of_day

    # Compute the next send time in user's timezone
    # If the reminder time has already passed today, schedule for tomorrow
    send_datetime_local =
      if Time.compare(now_local.time, reminder_time) == :lt do
        # Reminder time hasn't passed yet today
        DateTime.new!(Date.utc_today(), reminder_time, timezone)
      else
        # Reminder time has passed, schedule for tomorrow
        tomorrow = Date.add(Date.utc_today(), 1)
        DateTime.new!(tomorrow, reminder_time, timezone)
      end

    # The "for date" is the user's local date at send time
    reminder_date = DateTime.to_date(send_datetime_local)

    # Convert send time to UTC for job scheduling
    send_datetime_utc = DateTime.shift_zone!(send_datetime_local, "Etc/UTC")

    # Enqueue the reminder email job
    ReminderEmailJob.enqueue(user, reminder_date, send_datetime_utc)
  end
end
