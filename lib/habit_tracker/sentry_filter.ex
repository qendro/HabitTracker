defmodule HabitTracker.SentryFilter do
  @moduledoc """
  Filters and sanitizes events before sending to Sentry.
  
  This module ensures sensitive data is not sent to error tracking
  and filters out noise from expected errors.
  """

  @behaviour Sentry.EventFilter

  @doc """
  Filters events before sending to Sentry.
  
  Returns:
  - `false` to prevent the event from being sent
  - `true` to send the event as-is
  - `{:ok, updated_event}` to send a modified event
  """
  def exclude_exception?(%Plug.Conn.WrapperError{} = exception, _source) do
    case exception.reason do
      # Don't report expected Phoenix errors
      %Phoenix.Router.NoRouteError{} -> true
      %Phoenix.NotAcceptableError{} -> true
      # Report all other errors
      _ -> false
    end
  end

  def exclude_exception?(%Ecto.NoResultsError{}, _source), do: true
  def exclude_exception?(%Ecto.StaleEntryError{}, _source), do: true
  
  # Don't report rate limit errors as they're expected
  def exclude_exception?(%{message: "Rate limit exceeded" <> _}, _source), do: true
  
  def exclude_exception?(_exception, _source), do: false

  @doc """
  Sanitizes event data before sending to Sentry.
  
  Removes sensitive information like passwords, tokens, and API keys.
  """
  def before_send(event) do
    event
    |> sanitize_request_data()
    |> sanitize_extra_data()
    |> add_custom_context()
  end

  defp sanitize_request_data(%{request: request} = event) when is_map(request) do
    sanitized_request =
      request
      |> Map.update(:data, %{}, &sanitize_map/1)
      |> Map.update(:headers, %{}, &sanitize_headers/1)
      |> Map.update(:cookies, %{}, &sanitize_map/1)
      |> Map.update(:query_string, "", &sanitize_query_string/1)

    %{event | request: sanitized_request}
  end

  defp sanitize_request_data(event), do: event

  defp sanitize_extra_data(%{extra: extra} = event) when is_map(extra) do
    %{event | extra: sanitize_map(extra)}
  end

  defp sanitize_extra_data(event), do: event

  defp sanitize_map(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      if sensitive_key?(key) do
        {key, "[FILTERED]"}
      else
        {key, sanitize_value(value)}
      end
    end)
  end

  defp sanitize_map(value), do: value

  defp sanitize_value(value) when is_map(value), do: sanitize_map(value)
  defp sanitize_value(value) when is_list(value), do: Enum.map(value, &sanitize_value/1)
  defp sanitize_value(value), do: value

  defp sanitize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} ->
      if sensitive_header?(key) do
        {key, "[FILTERED]"}
      else
        {key, value}
      end
    end)
  end

  defp sanitize_headers(headers), do: headers

  defp sanitize_query_string(query_string) when is_binary(query_string) do
    query_string
    |> URI.decode_query()
    |> sanitize_map()
    |> URI.encode_query()
  end

  defp sanitize_query_string(query_string), do: query_string

  defp sensitive_key?(key) when is_atom(key), do: sensitive_key?(Atom.to_string(key))

  defp sensitive_key?(key) when is_binary(key) do
    key_lower = String.downcase(key)

    Enum.any?(
      [
        "password",
        "token",
        "secret",
        "api_key",
        "apikey",
        "authorization",
        "auth",
        "session",
        "cookie",
        "csrf",
        "credit_card",
        "ssn",
        "social_security"
      ],
      &String.contains?(key_lower, &1)
    )
  end

  defp sensitive_key?(_), do: false

  defp sensitive_header?(header) when is_binary(header) do
    header_lower = String.downcase(header)

    header_lower in [
      "authorization",
      "cookie",
      "set-cookie",
      "x-csrf-token",
      "x-api-key"
    ]
  end

  defp sensitive_header?(_), do: false

  defp add_custom_context(event) do
    # Add application version and environment info
    extra =
      Map.merge(event.extra || %{}, %{
        app_version: Application.spec(:habit_tracker, :vsn) |> to_string(),
        elixir_version: System.version(),
        otp_release: System.otp_release()
      })

    %{event | extra: extra}
  end
end
