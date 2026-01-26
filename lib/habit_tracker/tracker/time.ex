defmodule HabitTracker.Tracker.Time do
  @moduledoc false

  alias HabitTracker.Accounts
  alias HabitTracker.Accounts.User
  alias HabitTracker.Tracker.Habit

  def today_in_timezone(timezone) do
    case DateTime.shift_zone(DateTime.utc_now(:second), timezone) do
      {:ok, shifted} -> DateTime.to_date(shifted)
      _ -> DateTime.utc_now(:second) |> DateTime.to_date()
    end
  end

  def today_in_user_timezone(%User{timezone: timezone}), do: today_in_timezone(timezone)

  def today_in_user_timezone(%Habit{user: %User{timezone: timezone}}),
    do: today_in_timezone(timezone)

  def today_in_user_timezone(%Habit{user_id: user_id}) do
    Accounts.get_user!(user_id)
    |> Map.fetch!(:timezone)
    |> today_in_timezone()
  end

  def normalize_local_date(%Date{} = date, _timezone), do: {:ok, date}

  def normalize_local_date(%DateTime{} = dt, timezone) do
    case DateTime.shift_zone(dt, timezone) do
      {:ok, shifted} -> {:ok, DateTime.to_date(shifted)}
      _ -> {:ok, DateTime.to_date(dt)}
    end
  end

  def normalize_local_date(%NaiveDateTime{} = dt, timezone) do
    case DateTime.from_naive(dt, timezone) do
      {:ok, zoned} -> {:ok, DateTime.to_date(zoned)}
      _ -> {:ok, NaiveDateTime.to_date(dt)}
    end
  end

  def normalize_local_date(date, _timezone) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed} -> {:ok, parsed}
      _ -> {:error, :invalid_date}
    end
  end

  def normalize_local_date(nil, timezone), do: {:ok, today_in_timezone(timezone)}

  def normalize_local_date(_date, _timezone), do: {:error, :invalid_date}

  def normalize_local_date_for_habit(habit, date) do
    timezone = timezone_for(habit)
    normalize_local_date(date, timezone)
  end

  def period_to_date_range(:this_week, timezone), do: week_range(timezone)
  def period_to_date_range(:this_month, timezone), do: month_range(timezone)

  def goal_horizon_to_date_range(:weekly, timezone), do: week_range(timezone)
  def goal_horizon_to_date_range(:monthly, timezone), do: month_range(timezone)
  def goal_horizon_to_date_range(:yearly, timezone), do: year_range(timezone)

  defp week_range(timezone) do
    today = today_in_timezone(timezone)
    day_of_week = Date.day_of_week(today)
    start_of_week = Date.add(today, -(day_of_week - 1))
    end_of_week = Date.add(start_of_week, 6)

    {start_of_week, end_of_week}
  end

  defp month_range(timezone) do
    today = today_in_timezone(timezone)
    start_of_month = %{today | day: 1}
    end_of_month = Date.end_of_month(today)

    {start_of_month, end_of_month}
  end

  defp year_range(timezone) do
    today = today_in_timezone(timezone)
    start_of_year = %{today | month: 1, day: 1}
    end_of_year = %{today | month: 12, day: 31}

    {start_of_year, end_of_year}
  end

  defp timezone_for(%User{timezone: timezone}), do: timezone
  defp timezone_for(%Habit{user: %User{timezone: timezone}}), do: timezone

  defp timezone_for(%Habit{user_id: user_id}) do
    Accounts.get_user!(user_id)
    |> Map.fetch!(:timezone)
  end
end
