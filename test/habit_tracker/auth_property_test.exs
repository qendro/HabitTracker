defmodule HabitTracker.AuthPropertyTest do
  use HabitTracker.DataCase, async: true
  use ExUnitProperties

  import Swoosh.TestAssertions

  alias HabitTracker.Accounts
  alias HabitTracker.Accounts.User
  alias HabitTracker.Repo

  @timezones [
    "UTC",
    "America/New_York",
    "Europe/London",
    "Asia/Tokyo"
  ]

  @tag feature: "habit-tracker",
       property: 1,
       property_text: "Valid registration creates account and sends email"
  property "valid registration creates account and sends email" do
    check all(
            password <- StreamData.string(:alphanumeric, min_length: 8, max_length: 32),
            timezone <- StreamData.member_of(@timezones),
            max_runs: 100
          ) do
      flush_emails()

      email = unique_email()

      assert {:ok, user} =
               Accounts.register_user(%{
                 email: email,
                 password: password,
                 timezone: timezone
               })

      assert Accounts.get_user_by_email(email)

      assert {:ok, _email} =
               Accounts.deliver_user_confirmation_instructions(user, fn token ->
                 "[TOKEN]#{token}[TOKEN]"
               end)

      assert_email_sent(to: email, subject: "Confirmation instructions")
    end
  end

  @tag feature: "habit-tracker",
       property: 2,
       property_text: "Valid credentials authenticate successfully"
  property "valid credentials authenticate successfully" do
    check all(
            password <- StreamData.string(:alphanumeric, min_length: 8, max_length: 32),
            timezone <- StreamData.member_of(@timezones),
            max_runs: 100
          ) do
      email = unique_email()

      {:ok, user} =
        Accounts.register_user(%{
          email: email,
          password: password,
          timezone: timezone
        })

      {:ok, _user} =
        user
        |> change(confirmed_at: DateTime.utc_now(:second))
        |> Repo.update()

      assert %User{} = Accounts.get_user_by_email_and_password(email, password)
      assert is_nil(Accounts.get_user_by_email_and_password(email, "wrong-password"))
    end
  end

  @tag feature: "habit-tracker",
       property: 3,
       property_text: "Password reset request sends email"
  property "password reset request sends email" do
    check all(
            timezone <- StreamData.member_of(@timezones),
            max_runs: 100
          ) do
      flush_emails()

      email = unique_email()

      {:ok, user} =
        Accounts.register_user(%{
          email: email,
          password: "validpass123",
          timezone: timezone
        })

      assert {:ok, _email} =
               Accounts.deliver_user_reset_password_instructions(user, fn token ->
                 "[TOKEN]#{token}[TOKEN]"
               end)

      assert_email_sent(to: email, subject: "Reset password instructions")
    end
  end

  defp unique_email do
    "user#{System.unique_integer([:positive])}@example.com"
  end

  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
      {:emails, _} -> flush_emails()
    after
      0 -> :ok
    end
  end
end
