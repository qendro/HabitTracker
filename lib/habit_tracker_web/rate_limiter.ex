defmodule HabitTrackerWeb.RateLimiter do
  @moduledoc false

  @registration_limit 5
  @registration_window_ms 60 * 60 * 1000

  @login_limit 10
  @login_window_ms 15 * 60 * 1000

  @password_reset_limit 3
  @password_reset_window_ms 60 * 60 * 1000

  def check_registration(ip) when is_binary(ip) do
    if enabled?() do
      check_rate("registration:#{ip}", @registration_window_ms, @registration_limit)
    else
      :allow
    end
  end

  def check_registration(_), do: :allow

  def check_login(ip) when is_binary(ip) do
    if enabled?() do
      check_rate("login:#{ip}", @login_window_ms, @login_limit)
    else
      :allow
    end
  end

  def check_login(_), do: :allow

  def check_password_reset(email) when is_binary(email) do
    if enabled?() do
      normalized = String.downcase(String.trim(email))
      check_rate("password_reset:#{normalized}", @password_reset_window_ms, @password_reset_limit)
    else
      :allow
    end
  end

  def check_password_reset(_), do: :allow

  defp check_rate(key, scale_ms, limit) do
    case Hammer.check_rate(key, scale_ms, limit) do
      {:allow, _count} -> :allow
      {:deny, _count} -> :deny
      {:error, _reason} -> :allow
    end
  end

  defp enabled? do
    Application.get_env(:habit_tracker, :rate_limiting, true)
  end
end
