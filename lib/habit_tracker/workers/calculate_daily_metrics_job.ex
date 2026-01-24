defmodule HabitTracker.Workers.CalculateDailyMetricsJob do
  @moduledoc """
  Oban cron worker that runs daily at midnight UTC to calculate and store system metrics.

  This job:
  1. Calculates all admin metrics using live queries
  2. Stores metrics in daily_metrics table for historical tracking
  3. Runs at midnight UTC to capture the previous day's metrics

  Note: Starts with live queries; can be optimized with rollups later if needed.
  """

  use Oban.Worker, queue: :metrics

  alias HabitTracker.Admin

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Calculate metrics for yesterday (since we run at midnight)
    date = Date.add(Date.utc_today(), -1)

    metrics = Admin.calculate_daily_metrics(date)

    case Admin.store_daily_metrics(metrics) do
      {:ok, _metric} ->
        :ok

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
