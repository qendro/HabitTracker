defmodule HabitTracker.HealthJournal.Time do
  @moduledoc "Shared timezone conversion. Ambiguous or missing local event times require an explicit offset."
  def valid_zone?(zone), do: is_binary(zone) and Tzdata.zone_exists?(zone)
  def local(datetime, zone), do: DateTime.shift_zone!(datetime, zone)
  def today(zone), do: local(DateTime.utc_now(), zone) |> DateTime.to_date()

  def boundary(date, zone) do
    case DateTime.new(date, ~T[00:00:00], zone) do
      {:ok, dt} -> DateTime.shift_zone!(dt, "Etc/UTC")
      {:ambiguous, first, _} -> DateTime.shift_zone!(first, "Etc/UTC")
      {:gap, _, after_gap} -> DateTime.shift_zone!(after_gap, "Etc/UTC")
    end
  end

  def day_range(date, zone), do: {boundary(date, zone), boundary(Date.add(date, 1), zone)}

  def parse_local(value, zone) do
    with true <- valid_zone?(zone),
         {:ok, naive} <- NaiveDateTime.from_iso8601(value),
         {:ok, dt} <- DateTime.from_naive(naive, zone) do
      {:ok, DateTime.shift_zone!(dt, "Etc/UTC")}
    else
      _ -> {:error, :invalid_or_ambiguous_time}
    end
  end

  def input_value(dt, zone), do: local(dt, zone) |> Calendar.strftime("%Y-%m-%dT%H:%M:%S")
end
