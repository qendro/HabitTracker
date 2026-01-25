defmodule HabitTracker.Workers.ReminderEmailJob do
  @moduledoc """
  Oban worker for sending reminder emails to users.

  This job sends a reminder email to a user about their habits for a specific date.
  It includes retry logic and uniqueness constraints to prevent duplicate emails.
  """

  use Oban.Worker,
    queue: :emails,
    max_attempts: 3,
    unique: [period: 3600, fields: [:args], keys: [:user_id, :date, :hour]]

  alias HabitTracker.Accounts
  alias HabitTracker.Reminders
  alias HabitTracker.Tracker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "date" => date_string}}) do
    require Logger
    
    Logger.info("Processing reminder email job",
      user_id: user_id,
      date: date_string
    )
    
    user = Accounts.get_user!(user_id)
    date = Date.from_iso8601!(date_string)

    # Get user's habits scheduled for the date
    habits =
      user
      |> Tracker.list_habits()
      |> Enum.filter(&Tracker.is_scheduled?(&1, date))

    Logger.info("Found habits for reminder",
      user_id: user_id,
      habit_count: length(habits)
    )

    # Only send email if there are habits to remind about
    if habits != [] do
      case Reminders.send_reminder_email(user, habits) do
        {:ok, :sent} ->
          Logger.info("Reminder email sent successfully", user_id: user_id)
          :ok

        {:error, reason} ->
          Logger.error("Failed to send reminder email",
            user_id: user_id,
            error: inspect(reason)
          )
          {:error, reason}
      end
    else
      Logger.info("No habits to remind about, skipping email", user_id: user_id)
      :ok
    end
  end

  @doc """
  Enqueues a reminder email job for a user on a specific date.

  ## Examples

      iex> enqueue(user, ~D[2024-01-15], ~T[08:00:00])
      {:ok, %Oban.Job{}}

  """
  def enqueue(user, date, scheduled_at) do
    %{
      user_id: user.id,
      date: Date.to_iso8601(date),
      hour: scheduled_at.hour
    }
    |> new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end
end
