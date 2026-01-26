defmodule HabitTracker.Tracker.HabitForm do
  @moduledoc false

  import Ecto.Changeset

  alias HabitTracker.Tracker.Habit

  @default_icon "⭐"
  @default_color "#3B82F6"
  @default_schedule %{"type" => "daily"}
  @all_weekdays [1, 2, 3, 4, 5, 6, 7]

  @type_string_map %{
    "binary" => :binary,
    "numeric" => :numeric,
    "duration" => :duration
  }

  @horizon_string_map %{
    "daily" => :daily,
    "weekly" => :weekly,
    "monthly" => :monthly,
    "yearly" => :yearly
  }

  def default_habit do
    %Habit{
      type: :binary,
      goal_horizon: :daily,
      occurrence_schedule: @default_schedule,
      icon: @default_icon,
      color: @default_color
    }
  end

  def default_schedule_state(%Habit{} = habit) do
    schedule = habit.occurrence_schedule || @default_schedule
    schedule_type = schedule_type_from_occurrence(schedule) || "daily"
    weekdays = schedule_days(schedule)
    weekdays = if schedule_type == "daily" and weekdays == [], do: @all_weekdays, else: weekdays

    {schedule_type, weekdays}
  end

  def changeset(%Habit{} = habit, params) do
    params = to_habit_attrs(habit, params)

    habit
    |> Habit.changeset(params)
    |> validate_weekday_schedule()
    |> validate_frequency_goal_required()
  end

  def normalize_schedule_type(value) when is_atom(value), do: Atom.to_string(value)
  def normalize_schedule_type(value) when is_binary(value), do: String.downcase(value)
  def normalize_schedule_type(_), do: nil

  def normalize_weekdays(days) do
    days
    |> List.wrap()
    |> Enum.map(&normalize_weekday/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def schedule_days(schedule) when is_map(schedule) do
    days = Map.get(schedule, "days") || Map.get(schedule, :days) || []

    days
    |> List.wrap()
    |> Enum.map(&normalize_weekday/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def schedule_days(_), do: []

  def schedule_type_from_occurrence(%{"type" => type}), do: normalize_schedule_type(type)
  def schedule_type_from_occurrence(%{type: type}), do: normalize_schedule_type(type)
  def schedule_type_from_occurrence(_), do: nil

  def to_habit_attrs(%Habit{} = habit, params) do
    normalize_params(habit, params)
  end

  defp normalize_params(%Habit{} = habit, params) do
    params = stringify_keys(params || %{})
    params = trim_params(params, ["name", "description"])

    type = normalize_enum(params["type"], @type_string_map) || habit.type
    goal_horizon = normalize_enum(params["goal_horizon"], @horizon_string_map) || habit.goal_horizon
    icon = Map.get(params, "icon") || habit.icon || @default_icon
    color = Map.get(params, "color") || habit.color || @default_color

    schedule_type =
      params["schedule_type"]
      |> normalize_schedule_type()
      |> fallback_schedule_type(params, habit)

    weekdays =
      if Map.has_key?(params, "weekdays") do
        normalize_weekdays(params["weekdays"])
      else
        schedule_days(params["occurrence_schedule"]) |> default_weekdays(habit)
      end

    occurrence_schedule =
      case schedule_type do
        "weekdays" -> %{"type" => "weekdays", "days" => weekdays}
        "weekly" -> %{"type" => "weekly", "days" => weekdays}
        _ -> %{"type" => "daily"}
      end

    params
    |> Map.put("type", type)
    |> Map.put("goal_horizon", goal_horizon)
    |> Map.put("icon", icon)
    |> Map.put("color", color)
    |> Map.put("occurrence_schedule", occurrence_schedule)
    |> Map.drop(["schedule_type", "weekdays"])
    |> maybe_clear_target(type)
    |> maybe_clear_frequency_goal(goal_horizon)
  end

  defp fallback_schedule_type(nil, params, habit) do
    schedule_type_from_occurrence(params["occurrence_schedule"]) ||
      schedule_type_from_occurrence(habit.occurrence_schedule) ||
      "daily"
  end

  defp fallback_schedule_type(schedule_type, _params, _habit), do: schedule_type

  defp default_weekdays([], habit), do: schedule_days(habit.occurrence_schedule)
  defp default_weekdays(days, _habit), do: days

  defp normalize_enum(value, _mapping) when is_atom(value), do: value
  defp normalize_enum(value, mapping) when is_binary(value), do: Map.get(mapping, value)
  defp normalize_enum(_value, _mapping), do: nil

  defp normalize_weekday(day) when is_integer(day) and day in 1..7, do: day

  defp normalize_weekday(day) when is_binary(day) do
    case Integer.parse(day) do
      {value, _} when value in 1..7 -> value
      _ -> nil
    end
  end

  defp normalize_weekday(_), do: nil

  defp maybe_clear_target(params, :binary) do
    params
    |> Map.put("target_value", nil)
    |> Map.put("unit_label", nil)
  end

  defp maybe_clear_target(params, :duration) do
    Map.put(params, "unit_label", nil)
  end

  defp maybe_clear_target(params, _), do: params

  defp maybe_clear_frequency_goal(params, :daily) do
    Map.put(params, "frequency_goal", nil)
  end

  defp maybe_clear_frequency_goal(params, _), do: params

  defp validate_weekday_schedule(changeset) do
    case get_field(changeset, :occurrence_schedule) do
      %{"type" => "weekdays", "days" => days} when is_list(days) and length(days) > 0 ->
        changeset

      %{"type" => "weekdays"} ->
        add_error(changeset, :occurrence_schedule, "select at least one day")

      _ ->
        changeset
    end
  end

  defp validate_frequency_goal_required(changeset) do
    case get_field(changeset, :goal_horizon) do
      horizon when horizon in [:weekly, :monthly, :yearly] ->
        validate_required(changeset, [:frequency_goal])

      _ ->
        changeset
    end
  end

  defp stringify_keys(params) do
    Map.new(params, fn {key, value} -> {to_string(key), value} end)
  end

  defp trim_params(params, keys) do
    Enum.reduce(keys, params, fn key, acc ->
      case Map.get(acc, key) do
        value when is_binary(value) -> Map.put(acc, key, String.trim(value))
        _ -> acc
      end
    end)
  end
end
