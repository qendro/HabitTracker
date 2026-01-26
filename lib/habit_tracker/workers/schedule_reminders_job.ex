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
    require Logger
    
    # Get current UTC time
    now_utc = DateTime.utc_now()
    
    Logger.info("Running schedule reminders job", time: now_utc)

    # Find all users with reminders enabled
    settings =
      from(s in ReminderSettings,
        where: s.enabled == true,
        preload: [:user]
      )
      |> Repo.all()

    Logger.info("Found users with reminders enabled", count: length(settings))

    # Schedule reminder for each user
    Enum.each(settings, fn setting ->
      schedule_reminder_for_user(setting, now_utc)
    end)

    :ok
  end

  defp schedule_reminder_for_user(setting, now_utc) do
    require Logger
    
    user = setting.user
    timezone = user.timezone

    Logger.debug("Scheduling reminder for user",
      user_id: user.id,
      timezone: timezone,
      time_of_day: setting.time_of_day
    )

    # Get user's current local datetime
    now_local = DateTime.shift_zone!(now_utc, timezone)
    today_local = DateTime.to_date(now_local)

    # Get the configured time of day for reminders
    reminder_time = setting.time_of_day

    # Compute the next send time in user's timezone
    # If the reminder time has already passed today, schedule for tomorrow
    send_datetime_local =
      if Time.compare(now_local.time, reminder_time) == :lt do
        # Reminder time hasn't passed yet today
        DateTime.new!(today_local, reminder_time, timezone)
      else
        # Reminder time has passed, schedule for tomorrow
        tomorrow = Date.add(today_local, 1)
        DateTime.new!(tomorrow, reminder_time, timezone)
      end

    # The "for date" is the user's local date at send time
    reminder_date = DateTime.to_date(send_datetime_local)

    # Convert send time to UTC for job scheduling
    send_datetime_utc = DateTime.shift_zone!(send_datetime_local, "Etc/UTC")

    Logger.info("Enqueuing reminder email",
      user_id: user.id,
      reminder_date: reminder_date,
      scheduled_at: send_datetime_utc
    )

    # Enqueue the reminder email job
    case ReminderEmailJob.enqueue(user, reminder_date, send_datetime_utc) do
      {:ok, job} ->
        Logger.debug("Reminder job enqueued successfully",
          user_id: user.id,
          job_id: job.id
        )
        
      {:error, reason} ->
        Logger.error("Failed to enqueue reminder job",
          user_id: user.id,
          error: inspect(reason)
        )
    end
  end
end
