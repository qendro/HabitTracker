defmodule HabitTracker.Admin.DailyMetric do
  @moduledoc """
  Schema for storing daily system metrics.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "daily_metrics" do
    field :metric_date, :date
    field :total_users, :integer
    field :new_users_today, :integer
    field :dau, :integer
    field :wau, :integer
    field :mau, :integer
    field :total_habits, :integer
    field :completions_today, :integer
    field :avg_completion_rate, :float

    timestamps()
  end

  @doc false
  def changeset(daily_metric, attrs) do
    daily_metric
    |> cast(attrs, [
      :metric_date,
      :total_users,
      :new_users_today,
      :dau,
      :wau,
      :mau,
      :total_habits,
      :completions_today,
      :avg_completion_rate
    ])
    |> validate_required([
      :metric_date,
      :total_users,
      :new_users_today,
      :dau,
      :wau,
      :mau,
      :total_habits,
      :completions_today,
      :avg_completion_rate
    ])
    |> unique_constraint(:metric_date)
  end
end
