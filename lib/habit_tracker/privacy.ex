defmodule HabitTracker.Privacy do
  @moduledoc "Drop structured runtime reports: OTP crash reports can inspect LiveView assigns containing health data."
  def install do
    :logger.add_primary_filter(:health_journal_privacy, {&__MODULE__.filter/2, nil})
  end

  def filter(%{level: level, msg: {:report, _}}, _) when level in [:debug, :info, :notice],
    do: :stop

  def filter(%{msg: {:report, _}} = event, _),
    do: %{
      event
      | msg: {:string, ~c"Runtime report omitted to protect private journal data"},
        meta: Map.take(event.meta, [:time, :gl])
    }

  def filter(event, _), do: event
end
