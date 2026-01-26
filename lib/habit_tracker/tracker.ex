defmodule HabitTracker.Tracker do
  @moduledoc """
  The Tracker context.
  """

  alias HabitTracker.Accounts.User
  alias HabitTracker.Tracker.{Dashboard, Habits, Logs, Schedule, Stats}
  alias HabitTracker.Tracker.{Habit, HabitLog}

  # Helper to check if readonly mode is active
  defp check_readonly_mode(scope) do
    if Map.get(scope, :readonly_mode, false) do
      {:error, :readonly_mode}
    else
      :ok
    end
  end

  def create_habit(%User{} = user, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      Habits.create_habit(user, attrs)
    end
  end

  def update_habit(%Habit{} = habit, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      Habits.update_habit(habit, attrs)
    end
  end

  def delete_habit(%Habit{} = habit, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      Habits.delete_habit(habit)
    end
  end

  def list_habits(%User{} = user), do: Habits.list_habits(user)

  def get_habit!(%User{} = user, id), do: Habits.get_habit!(user, id)

  def get_logs_for_date(%User{} = user, %Date{} = local_date),
    do: Logs.get_logs_for_date(user, local_date)

  def get_log(%Habit{} = habit, %Date{} = local_date),
    do: Logs.get_log(habit, local_date)

  def log_habit(%Habit{} = habit, local_date, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      Logs.log_habit(habit, local_date, attrs)
    end
  end

  def update_habit_log(%HabitLog{} = log, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      Logs.update_habit_log(log, attrs)
    end
  end

  def is_scheduled?(%Habit{} = habit, %Date{} = date), do: Schedule.scheduled?(habit, date)

  def scheduled_dates(%Habit{} = habit, range), do: Schedule.scheduled_dates(habit, range)

  def calculate_streak(%Habit{} = habit, as_of_date \\ nil),
    do: Stats.calculate_streak(habit, as_of_date)

  def completion_rate(%Habit{} = habit, period, timezone),
    do: Stats.completion_rate(habit, period, timezone)

  def frequency_progress(%Habit{} = habit, timezone),
    do: Stats.frequency_progress(habit, timezone)

  def today_dashboard(%User{} = user, local_date \\ nil),
    do: Dashboard.today_dashboard(user, local_date)

  def reorder_habits(%User{} = user, habit_ids) when is_list(habit_ids),
    do: Habits.reorder_habits(user, habit_ids)
end
