defmodule HabitTrackerWeb.RateLimiterTest do
  use ExUnit.Case, async: false

  alias HabitTrackerWeb.RateLimiter

  setup do
    original = Application.get_env(:habit_tracker, :rate_limiting, true)
    Application.put_env(:habit_tracker, :rate_limiting, true)

    on_exit(fn ->
      Application.put_env(:habit_tracker, :rate_limiting, original)
    end)

    :ok
  end

  test "login rate limit enforcement" do
    ip = unique_id("ip")
    _ = Hammer.delete_buckets("login:#{ip}")

    for _ <- 1..10 do
      assert RateLimiter.check_login(ip) == :allow
    end

    assert RateLimiter.check_login(ip) == :deny
  end

  defp unique_id(prefix) do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end
end
