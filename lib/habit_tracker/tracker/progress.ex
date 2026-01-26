defmodule HabitTracker.Tracker.Progress do
  @moduledoc false

  alias HabitTracker.Tracker.Habit

  def calculate_progress(%Habit{type: :binary}, log) do
    %{
      type: :binary,
      status: if(log, do: log.status, else: :not_complete)
    }
  end

  def calculate_progress(%Habit{type: :numeric, target_value: target} = habit, log) do
    current = if log && log.numeric_value, do: log.numeric_value, else: 0

    %{
      type: :numeric,
      current: current,
      target: target,
      unit: habit.unit_label,
      percentage: calculate_percentage(current, target),
      status: if(log, do: log.status, else: :not_complete)
    }
  end

  def calculate_progress(%Habit{type: :duration, target_value: target} = habit, log) do
    current = if log && log.duration_minutes, do: log.duration_minutes, else: 0

    %{
      type: :duration,
      current: current,
      target: target,
      unit: habit.unit_label || "minutes",
      percentage: calculate_percentage(current, target),
      status: if(log, do: log.status, else: :not_complete)
    }
  end

  defp calculate_percentage(current, target) when is_integer(current) and is_integer(target) do
    if target > 0 do
      min(100, div(current * 100, target))
    else
      0
    end
  end

  defp calculate_percentage(_current, _target), do: 0
end
