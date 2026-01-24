defmodule HabitTracker.Reminders do
  @moduledoc """
  The Reminders context handles email reminder settings and email composition.
  """

  import Swoosh.Email

  alias HabitTracker.Mailer
  alias HabitTracker.Repo
  alias HabitTracker.Reminders.ReminderSettings

  @doc """
  Gets the reminder settings for a user.
  Creates default settings if none exist.

  ## Examples

      iex> get_reminder_settings(user)
      %ReminderSettings{...}

  """
  def get_reminder_settings(user) do
    case Repo.get_by(ReminderSettings, user_id: user.id) do
      nil ->
        %ReminderSettings{user_id: user.id}

      settings ->
        settings
    end
  end

  @doc """
  Updates reminder settings for a user.

  ## Examples

      iex> update_reminder_settings(user, %{enabled: true})
      {:ok, %ReminderSettings{}}

      iex> update_reminder_settings(user, %{enabled: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def update_reminder_settings(user, attrs) do
    settings = get_reminder_settings(user)

    settings
    |> ReminderSettings.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert_or_update()
  end

  @doc """
  Composes a reminder email for a user with their habits.

  ## Examples

      iex> compose_reminder_email(user, habits)
      %Swoosh.Email{...}

  """
  def compose_reminder_email(user, habits) do
    habit_list =
      habits
      |> Enum.map(fn habit -> "  • #{habit.name}" end)
      |> Enum.join("\n")

    body = """
    Hi #{user.email},

    Don't forget to track your habits today!

    Your habits for today:
    #{habit_list}

    Log in to track your progress: #{app_url()}

    Keep up the great work!

    ---
    HabitTracker
    """

    new()
    |> to(user.email)
    |> from(sender_email())
    |> subject("Daily Habit Reminder")
    |> text_body(body)
  end

  @doc """
  Composes a confirmation email for a new user registration.

  ## Examples

      iex> compose_confirmation_email(user, url)
      %Swoosh.Email{...}

  """
  def compose_confirmation_email(user, url) do
    body = """
    Hi #{user.email},

    Welcome to HabitTracker!

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this email.

    ---
    HabitTracker
    """

    new()
    |> to(user.email)
    |> from(sender_email())
    |> subject("Confirm your HabitTracker account")
    |> text_body(body)
  end

  @doc """
  Composes a password reset email.

  ## Examples

      iex> compose_password_reset_email(user, url)
      %Swoosh.Email{...}

  """
  def compose_password_reset_email(user, url) do
    body = """
    Hi #{user.email},

    You requested to reset your password.

    You can reset your password by visiting the URL below:

    #{url}

    This link will expire in 1 hour.

    If you didn't request this email, please ignore it.

    ---
    HabitTracker
    """

    new()
    |> to(user.email)
    |> from(sender_email())
    |> subject("Reset your HabitTracker password")
    |> text_body(body)
  end

  @doc """
  Sends a reminder email to a user.

  ## Examples

      iex> send_reminder_email(user, habits)
      {:ok, :sent}

  """
  def send_reminder_email(user, habits) do
    email = compose_reminder_email(user, habits)

    case Mailer.deliver(email) do
      {:ok, _metadata} -> {:ok, :sent}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp sender_email do
    {"HabitTracker", Application.get_env(:habit_tracker, :sender_email, "noreply@habittracker.com")}
  end

  defp app_url do
    Application.get_env(:habit_tracker, :app_url, "https://habittracker.com")
  end
end
