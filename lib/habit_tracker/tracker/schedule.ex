defmodule HabitTracker.Tracker.Schedule do
  @moduledoc false

  alias HabitTracker.Tracker.Habit

  @weekday_map %{
    "monday" => 1,
    "mon" => 1,
    "tuesday" => 2,
    "tue" => 2,
    "wednesday" => 3,
    "wed" => 3,
    "thursday" => 4,
    "thu" => 4,
    "friday" => 5,
    "fri" => 5,
    "saturday" => 6,
    "sat" => 6,
    "sunday" => 7,
    "sun" => 7
  }

  def scheduled?(%Habit{occurrence_schedule: schedule}, %Date{} = date),
    do: scheduled?(schedule, date)

  def scheduled?(schedule, %Date{} = date) when is_map(schedule) do
    scheduled_for_date?(schedule_type(schedule), schedule_days(schedule), date)
  end

  def scheduled?(_schedule, _date), do: false

  def scheduled_dates(%Habit{} = habit, %Date.Range{} = range) do
    range
    |> Enum.filter(&scheduled?(habit, &1))
  end

  def scheduled_dates(%Habit{} = habit, {from_date, to_date})
      when is_struct(from_date, Date) and is_struct(to_date, Date) do
    if Date.compare(from_date, to_date) == :gt do
      []
    else
      Date.range(from_date, to_date)
      |> Enum.filter(&scheduled?(habit, &1))
    end
  end

  def schedule_type(%{"type" => type}), do: normalize_schedule_type(type)
  def schedule_type(%{type: type}), do: normalize_schedule_type(type)
  def schedule_type(_), do: nil

  def schedule_days(schedule) do
    days =
      Map.get(schedule, "days") ||
        Map.get(schedule, :days) ||
        schedule_day_flags(schedule)

    days
    |> List.wrap()
    |> Enum.map(&normalize_weekday/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_schedule_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_schedule_type(type) when is_binary(type), do: String.downcase(type)
  defp normalize_schedule_type(_), do: nil

  defp schedule_day_flags(schedule) when is_map(schedule) do
    schedule
    |> Enum.flat_map(fn {key, value} ->
      if value == true do
        [normalize_weekday(key)]
      else
        []
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp schedule_day_flags(_), do: []

  defp normalize_weekday(day) when is_integer(day) and day in 1..7, do: day

  defp normalize_weekday(day) when is_atom(day),
    do: day |> Atom.to_string() |> normalize_weekday()

  defp normalize_weekday(day) when is_binary(day), do: Map.get(@weekday_map, String.downcase(day))
  defp normalize_weekday(_), do: nil

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
