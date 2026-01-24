defmodule HabitTracker.SecurityTest do
  use HabitTracker.DataCase, async: true

  alias HabitTracker.Security

  describe "log_event/2" do
    test "logs failed login events" do
      assert :ok =
               Security.log_event(:failed_login, %{
                 email: "test@example.com",
                 ip: "192.168.1.1"
               })
    end

    test "logs successful login events" do
      assert :ok =
               Security.log_event(:successful_login, %{
                 user_id: 1,
                 email: "test@example.com",
                 ip: "192.168.1.1"
               })
    end

    test "logs password reset requests" do
      assert :ok =
               Security.log_event(:password_reset_request, %{
                 email: "test@example.com",
                 ip: "192.168.1.1"
               })
    end

    test "logs password changes" do
      assert :ok =
               Security.log_event(:password_changed, %{
                 user_id: 1,
                 ip: "192.168.1.1"
               })
    end

    test "logs account deletion" do
      assert :ok =
               Security.log_event(:account_deleted, %{
                 user_id: 1,
                 email: "test@example.com",
                 ip: "192.168.1.1"
               })
    end

    test "logs privilege escalation attempts" do
      assert :ok =
               Security.log_event(:privilege_escalation_attempt, %{
                 user_id: 1,
                 action: "access_admin_panel",
                 ip: "192.168.1.1"
               })
    end

    test "logs admin actions" do
      assert :ok =
               Security.log_event(:admin_action, %{
                 admin_id: 1,
                 action: "delete_user",
                 target_user_id: 5,
                 success: true
               })
    end

    test "logs rate limit exceeded" do
      assert :ok =
               Security.log_event(:rate_limit_exceeded, %{
                 endpoint: "login",
                 ip: "192.168.1.1",
                 identifier: "test@example.com"
               })
    end

    test "logs invalid token usage" do
      assert :ok =
               Security.log_event(:invalid_token, %{
                 token_type: "reset_password",
                 ip: "192.168.1.1"
               })
    end

    test "logs suspicious activity" do
      assert :ok =
               Security.log_event(:suspicious_activity, %{
                 description: "Multiple failed login attempts",
                 user_id: 1,
                 ip: "192.168.1.1"
               })
    end
  end

  describe "sanitize_email/1" do
    test "returns nil for nil input" do
      assert Security.sanitize_email(nil) == nil
    end

    test "truncates long emails" do
      long_email = String.duplicate("a", 200) <> "@example.com"
      sanitized = Security.sanitize_email(long_email)
      assert String.length(sanitized) == 160
    end

    test "removes newlines from email" do
      email_with_newlines = "test@example.com\n\r"
      sanitized = Security.sanitize_email(email_with_newlines)
      refute String.contains?(sanitized, "\n")
      refute String.contains?(sanitized, "\r")
    end

    test "preserves normal email" do
      email = "test@example.com"
      assert Security.sanitize_email(email) == email
    end
  end

  describe "sanitize_input/1" do
    test "returns nil for nil input" do
      assert Security.sanitize_input(nil) == nil
    end

    test "escapes HTML tags" do
      input = "<script>alert('xss')</script>"
      sanitized = Security.sanitize_input(input)
      assert sanitized == "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    end

    test "escapes special characters" do
      input = "<>&'\""
      sanitized = Security.sanitize_input(input)
      assert String.contains?(sanitized, "&lt;")
      assert String.contains?(sanitized, "&gt;")
      assert String.contains?(sanitized, "&amp;")
    end

    test "preserves normal text" do
      input = "Normal text"
      sanitized = Security.sanitize_input(input)
      assert sanitized == input
    end

    test "returns non-string input unchanged" do
      assert Security.sanitize_input(123) == 123
      assert Security.sanitize_input(%{key: "value"}) == %{key: "value"}
    end
  end

  describe "safe_string?/1" do
    test "returns true for alphanumeric strings" do
      assert Security.safe_string?("username123")
      assert Security.safe_string?("user_name")
      assert Security.safe_string?("user-name")
      assert Security.safe_string?("user.name")
      assert Security.safe_string?("user@example.com")
    end

    test "returns false for strings with special characters" do
      refute Security.safe_string?("user<script>")
      refute Security.safe_string?("user;DROP TABLE")
      refute Security.safe_string?("user\n")
      refute Security.safe_string?("user name")
    end

    test "returns false for non-string input" do
      refute Security.safe_string?(123)
      refute Security.safe_string?(nil)
      refute Security.safe_string?(%{})
    end
  end

  describe "verify_bcrypt_cost/0" do
    test "returns configured bcrypt cost factor" do
      cost = Security.verify_bcrypt_cost()
      # In test environment, cost is set to 1 for faster tests
      # In production, it should be 12
      assert cost in [1, 12]
    end
  end

  describe "https_enforced?/0" do
    test "returns boolean indicating HTTPS enforcement" do
      result = Security.https_enforced?()
      assert is_boolean(result)
    end
  end

  describe "validate_password_strength/1" do
    test "accepts valid passwords" do
      assert {:ok, "password123"} = Security.validate_password_strength("password123")
      assert {:ok, "12345678"} = Security.validate_password_strength("12345678")
    end

    test "rejects passwords that are too short" do
      assert {:error, "Password must be at least 8 characters"} =
               Security.validate_password_strength("short")
    end

    test "rejects passwords that are too long" do
      long_password = String.duplicate("a", 73)

      assert {:error, "Password must be at most 72 characters"} =
               Security.validate_password_strength(long_password)
    end

    test "rejects non-string passwords" do
      assert {:error, "Password must be a string"} = Security.validate_password_strength(123)
      assert {:error, "Password must be a string"} = Security.validate_password_strength(nil)
    end
  end
end
