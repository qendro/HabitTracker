defmodule HabitTracker.Tracker.Dashboard do
  @moduledoc false

  alias HabitTracker.Accounts.User
  alias HabitTracker.Tracker.{Habits, Logs, Progress, Schedule, Stats, Time}

  def today_dashboard(%User{} = user, local_date \\ nil) do
    local_date = local_date || Time.today_in_timezone(user.timezone)

    habits = Habits.list_habits(user)
    scheduled_habits = Enum.filter(habits, &Schedule.scheduled?(&1, local_date))

    habit_ids = Enum.map(scheduled_habits, & &1.id)

    logs_by_habit = Logs.logs_for_date(user.id, local_date, habit_ids)

    today = Time.today_in_timezone(user.timezone)
    effective_date = if Date.compare(local_date, today) == :gt, do: today, else: local_date

    completed_dates_by_habit = Logs.completed_dates_for_habits(habit_ids, effective_date)
    streaks_by_habit = Stats.streaks_for_habits(scheduled_habits, completed_dates_by_habit, effective_date)

    Enum.map(scheduled_habits, fn habit ->
      log = Map.get(logs_by_habit, habit.id)
      streak = Map.get(streaks_by_habit, habit.id, 0)
      is_complete = log && log.status == :complete

      %{
        habit: habit,
        log: log,
        streak: streak,
        is_complete: is_complete,
        progress: Progress.calculate_progress(habit, log)
      }
    end)
  end
end
