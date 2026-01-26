defmodule HabitTracker.Tracker.Stats do
  @moduledoc false

  import Ecto.Query, warn: false

  alias HabitTracker.Repo
  alias HabitTracker.Tracker.{Habit, HabitLog, Schedule, Time}

  def calculate_streak(%Habit{} = habit, as_of_date \\ nil) do
    habit = Repo.preload(habit, :user)
    schedule = habit.occurrence_schedule || %{}
    schedule_type = Schedule.schedule_type(schedule)
    schedule_days = Schedule.schedule_days(schedule)

    if schedule_type != "daily" and schedule_days == [] do
      0
    else
      today = Time.today_in_user_timezone(habit)

      effective_as_of =
        case Time.normalize_local_date_for_habit(habit, as_of_date) do
          {:ok, date} -> date
          _ -> today
        end

      effective_date =
        case Date.compare(effective_as_of, today) do
          :gt -> today
          _ -> effective_as_of
        end

      completed_dates = completed_log_dates(habit.id, effective_date)

      if MapSet.size(completed_dates) == 0 do
        0
      else
        min_completed =
          completed_dates
          |> MapSet.to_list()
          |> Enum.min_by(&Date.to_erl/1)

        count_streak(
          effective_date,
          min_completed,
          completed_dates,
          schedule_type,
          schedule_days,
          0
        )
      end
    end
  end

  def completion_rate(%Habit{} = habit, period, timezone) when period in [:this_week, :this_month] do
    {start_date, end_date} = Time.period_to_date_range(period, timezone)

    scheduled_dates = Schedule.scheduled_dates(habit, {start_date, end_date})
    total_scheduled = length(scheduled_dates)

    if total_scheduled > 0 do
      completed =
        from(log in HabitLog,
          where: log.habit_id == ^habit.id,
          where: log.local_date >= ^start_date,
          where: log.local_date <= ^end_date,
          where: log.status == :complete,
          select: count(log.id)
        )
        |> Repo.one()

      completed / total_scheduled
    else
      0.0
    end
  end

  def frequency_progress(%Habit{goal_horizon: :daily} = _habit, _timezone) do
    {0, 0}
  end

  def frequency_progress(%Habit{} = habit, timezone) do
    target = habit.frequency_goal || 0

    {start_date, end_date} = Time.goal_horizon_to_date_range(habit.goal_horizon, timezone)

    completed =
      from(log in HabitLog,
        where: log.habit_id == ^habit.id,
        where: log.local_date >= ^start_date,
        where: log.local_date <= ^end_date,
        where: log.status == :complete,
        select: count(log.id)
      )
      |> Repo.one()

    {completed, target}
  end

  def streaks_for_habits(habits, completed_dates_by_habit, %Date{} = effective_date)
      when is_list(habits) do
    Enum.reduce(habits, %{}, fn habit, acc ->
      schedule = habit.occurrence_schedule || %{}
      schedule_type = Schedule.schedule_type(schedule)
      schedule_days = Schedule.schedule_days(schedule)
      completed_dates = Map.get(completed_dates_by_habit, habit.id, MapSet.new())

      streak =
        if schedule_type != "daily" and schedule_days == [] do
          0
        else
          if MapSet.size(completed_dates) == 0 do
            0
          else
            min_completed =
              completed_dates
              |> MapSet.to_list()
              |> Enum.min_by(&Date.to_erl/1)

            count_streak(
              effective_date,
              min_completed,
              completed_dates,
              schedule_type,
              schedule_days,
              0
            )
          end
        end

      Map.put(acc, habit.id, streak)
    end)
  end

  defp completed_log_dates(habit_id, effective_date) do
    HabitLog
    |> where(
      [l],
      l.habit_id == ^habit_id and l.status == :complete and l.local_date <= ^effective_date
    )
    |> select([l], l.local_date)
    |> Repo.all()
    |> MapSet.new()
  end

  defp count_streak(current_date, min_date, completed_dates, schedule_type, schedule_days, streak) do
    cond do
      Date.compare(current_date, min_date) == :lt ->
        streak

      scheduled_for_date?(schedule_type, schedule_days, current_date) ->
        if MapSet.member?(completed_dates, current_date) do
          count_streak(
            Date.add(current_date, -1),
            min_date,
            completed_dates,
            schedule_type,
            schedule_days,
            streak + 1
          )
        else
          streak
        end

      true ->
        count_streak(
          Date.add(current_date, -1),
          min_date,
          completed_dates,
          schedule_type,
          schedule_days,
          streak
        )
    end
  end

  defp scheduled_for_date?(schedule_type, schedule_days, date) do
    cond do
      schedule_type == "daily" ->
        true

      schedule_type in ["weekdays", "weekly"] ->
        Date.day_of_week(date) in schedule_days

      schedule_type in [nil, ""] and schedule_days != [] ->
        Date.day_of_week(date) in schedule_days

      true ->
        false
    end
  end
end
