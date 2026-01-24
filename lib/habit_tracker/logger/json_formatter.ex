defmodule HabitTracker.Logger.JSONFormatter do
  @moduledoc """
  JSON formatter for structured logging in production.
  
  Outputs logs in JSON format for easy parsing by log aggregation services.
  """

  @doc """
  Formats log messages as JSON.
  
  ## Examples
  
      iex> format(:info, "User logged in", {{2024, 1, 1}, {12, 0, 0, 0}}, [user_id: 123])
      ~s({"timestamp":"2024-01-01T12:00:00.000Z","level":"info","message":"User logged in","user_id":123}\n)
  """
  def format(level, message, timestamp, metadata) do
    %{
      timestamp: format_timestamp(timestamp),
      level: level,
      message: IO.chardata_to_string(message)
    }
    |> add_metadata(metadata)
    |> Jason.encode!()
    |> Kernel.<>("\n")
  rescue
    _ ->
      # Fallback to simple format if JSON encoding fails
      "#{inspect(level)} #{message}\n"
  end

  defp format_timestamp({{year, month, day}, {hour, minute, second, millisecond}}) do
    # Format as ISO 8601
    date = Date.new!(year, month, day)
    time = Time.new!(hour, minute, second, millisecond * 1000)
    
    datetime = DateTime.new!(date, time, "Etc/UTC")
    DateTime.to_iso8601(datetime)
  end

  defp add_metadata(log_map, metadata) do
    metadata
    |> Enum.reduce(log_map, fn {key, value}, acc ->
      Map.put(acc, key, sanitize_metadata_value(value))
    end)
  end

  defp sanitize_metadata_value(value) when is_binary(value), do: value
  defp sanitize_metadata_value(value) when is_number(value), do: value
  defp sanitize_metadata_value(value) when is_boolean(value), do: value
  defp sanitize_metadata_value(value) when is_atom(value), do: Atom.to_string(value)
  defp sanitize_metadata_value(value) when is_list(value) do
    Enum.map(value, &sanitize_metadata_value/1)
  end
  defp sanitize_metadata_value(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, sanitize_metadata_value(v)} end)
  end
  defp sanitize_metadata_value(value), do: inspect(value)
end
