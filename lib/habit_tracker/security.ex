defmodule HabitTracker.Security do
  @moduledoc """
  Security module for logging security-relevant events and providing
  security utilities for the application.
  
  This module handles:
  - Security event logging
  - Input validation and sanitization
  - Security event tracking
  """

  require Logger

  @doc """
  Logs a security event with relevant metadata.
  
  ## Event Types
  - :failed_login - Failed login attempt
  - :successful_login - Successful login
  - :password_reset_request - Password reset requested
  - :password_changed - Password successfully changed
  - :account_deleted - Account deletion initiated
  - :privilege_escalation_attempt - Attempt to escalate privileges
  - :admin_action - Admin performed a privileged action
  - :rate_limit_exceeded - Rate limit exceeded
  - :invalid_token - Invalid or expired token used
  - :suspicious_activity - Other suspicious activity
  
  ## Examples
  
      iex> Security.log_event(:failed_login, %{email: "user@example.com", ip: "192.168.1.1"})
      :ok
      
      iex> Security.log_event(:admin_action, %{admin_id: 1, action: "delete_user", target_user_id: 5})
      :ok
  """
  def log_event(event_type, metadata \\ %{})

  def log_event(:failed_login, metadata) do
    Logger.warning("Security: Failed login attempt",
      event: :failed_login,
      email: sanitize_email(metadata[:email]),
      ip: metadata[:ip],
      user_agent: metadata[:user_agent]
    )
  end

  def log_event(:successful_login, metadata) do
    Logger.info("Security: Successful login",
      event: :successful_login,
      user_id: metadata[:user_id],
      email: sanitize_email(metadata[:email]),
      ip: metadata[:ip]
    )
  end

  def log_event(:password_reset_request, metadata) do
    Logger.info("Security: Password reset requested",
      event: :password_reset_request,
      email: sanitize_email(metadata[:email]),
      ip: metadata[:ip]
    )
  end

  def log_event(:password_changed, metadata) do
    Logger.info("Security: Password changed",
      event: :password_changed,
      user_id: metadata[:user_id],
      ip: metadata[:ip]
    )
  end

  def log_event(:account_deleted, metadata) do
    Logger.info("Security: Account deletion initiated",
      event: :account_deleted,
      user_id: metadata[:user_id],
      email: sanitize_email(metadata[:email]),
      ip: metadata[:ip]
    )
  end

  def log_event(:privilege_escalation_attempt, metadata) do
    Logger.error("Security: Privilege escalation attempt detected",
      event: :privilege_escalation_attempt,
      user_id: metadata[:user_id],
      attempted_action: metadata[:action],
      ip: metadata[:ip]
    )
  end

  def log_event(:admin_action, metadata) do
    Logger.info("Security: Admin action performed",
      event: :admin_action,
      admin_id: metadata[:admin_id],
      action: metadata[:action],
      target_user_id: metadata[:target_user_id],
      success: metadata[:success]
    )
  end

  def log_event(:rate_limit_exceeded, metadata) do
    Logger.warning("Security: Rate limit exceeded",
      event: :rate_limit_exceeded,
      endpoint: metadata[:endpoint],
      ip: metadata[:ip],
      identifier: metadata[:identifier]
    )
  end

  def log_event(:invalid_token, metadata) do
    Logger.warning("Security: Invalid or expired token used",
      event: :invalid_token,
      token_type: metadata[:token_type],
      ip: metadata[:ip]
    )
  end

  def log_event(:suspicious_activity, metadata) do
    Logger.warning("Security: Suspicious activity detected",
      event: :suspicious_activity,
      description: metadata[:description],
      user_id: metadata[:user_id],
      ip: metadata[:ip]
    )
  end

  def log_event(event_type, metadata) do
    Logger.warning("Security: Unknown event type",
      event: event_type,
      metadata: metadata
    )
  end

  @doc """
  Sanitizes an email address for logging by truncating to prevent log injection.
  """
  def sanitize_email(nil), do: nil

  def sanitize_email(email) when is_binary(email) do
    email
    |> String.slice(0, 160)
    |> String.replace(~r/[\r\n]/, "")
  end

  @doc """
  Sanitizes user input to prevent XSS and injection attacks.
  This is a basic sanitization - Phoenix already provides protection
  via HEEx templates, but this provides an additional layer.
  
  ## Examples
  
      iex> Security.sanitize_input("<script>alert('xss')</script>")
      "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
      
      iex> Security.sanitize_input("Normal text")
      "Normal text"
  """
  def sanitize_input(nil), do: nil

  def sanitize_input(input) when is_binary(input) do
    input
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def sanitize_input(input), do: input

  @doc """
  Validates that a string contains only safe characters.
  Useful for validating identifiers, usernames, etc.
  
  ## Examples
  
      iex> Security.safe_string?("valid_username123")
      true
      
      iex> Security.safe_string?("invalid<script>")
      false
  """
  def safe_string?(string) when is_binary(string) do
    # Check for newlines and other control characters first
    if String.contains?(string, ["\n", "\r", "\t"]) do
      false
    else
      String.match?(string, ~r/^[a-zA-Z0-9_\-\.@]+$/)
    end
  end

  def safe_string?(_), do: false

  @doc """
  Extracts client IP address from connection, handling proxies.
  """
  def get_client_ip(conn) do
    # Check for X-Forwarded-For header (from proxies/load balancers)
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] ->
        # Take the first IP in the chain (original client)
        ip
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        # Fall back to remote_ip
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end

  @doc """
  Gets user agent from connection for logging.
  """
  def get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [user_agent | _] -> String.slice(user_agent, 0, 255)
      [] -> nil
    end
  end

  @doc """
  Verifies that bcrypt is configured with appropriate cost factor.
  Returns the current cost factor.
  """
  def verify_bcrypt_cost do
    # Bcrypt default cost is 12, which is appropriate for security
    # This function can be used in tests to verify configuration
    Application.get_env(:bcrypt_elixir, :log_rounds, 12)
  end

  @doc """
  Checks if HTTPS is enforced in the current environment.
  """
  def https_enforced? do
    config = Application.get_env(:habit_tracker, HabitTrackerWeb.Endpoint, [])
    Keyword.get(config, :force_ssl, false) != false
  end

  @doc """
  Validates that a password meets security requirements.
  Returns {:ok, password} or {:error, reason}.
  """
  def validate_password_strength(password) when is_binary(password) do
    cond do
      String.length(password) < 8 ->
        {:error, "Password must be at least 8 characters"}

      String.length(password) > 72 ->
        {:error, "Password must be at most 72 characters"}

      true ->
        {:ok, password}
    end
  end

  def validate_password_strength(_), do: {:error, "Password must be a string"}
end
