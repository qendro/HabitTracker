defmodule HabitTrackerWeb.RateLimiter do
  @moduledoc "Ten password attempts per fifteen minutes per connection IP."
  def check_login(ip) when is_binary(ip) do
    if Application.get_env(:habit_tracker, :rate_limiting, true) do
      case Hammer.check_rate("login:#{ip}", 15 * 60 * 1000, 10) do
        {:allow, _} -> :allow
        _ -> :deny
      end
    else
      :allow
    end
  end
end
