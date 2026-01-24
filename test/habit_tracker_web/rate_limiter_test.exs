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

  test "registration rate limit enforcement" do
    ip = unique_id("ip")
    _ = Hammer.delete_buckets("registration:#{ip}")

    for _ <- 1..5 do
      assert RateLimiter.check_registration(ip) == :allow
    end

    assert RateLimiter.check_registration(ip) == :deny
  end

  test "login rate limit enforcement" do
    ip = unique_id("ip")
    _ = Hammer.delete_buckets("login:#{ip}")

    for _ <- 1..10 do
      assert RateLimiter.check_login(ip) == :allow
    end

    assert RateLimiter.check_login(ip) == :deny
  end

  test "password reset rate limit enforcement" do
    email = "User#{unique_id("reset")}@Example.com"
    normalized = String.downcase(String.trim(email))
    _ = Hammer.delete_buckets("password_reset:#{normalized}")

    for _ <- 1..3 do
      assert RateLimiter.check_password_reset(email) == :allow
    end

    assert RateLimiter.check_password_reset(email) == :deny
  end

  defp unique_id(prefix) do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end
end
