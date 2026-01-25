defmodule HabitTracker.Accounts.UserNotifier do
  import Swoosh.Email

  alias HabitTracker.Mailer

  require Logger

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    sender_email = Application.get_env(:habit_tracker, :sender_email, "noreply@habittracker.com")
    
    Logger.info("Sending email",
      to: recipient,
      subject: subject,
      from: sender_email
    )
    
    email =
      new()
      |> to(recipient)
      |> from({"HabitTracker", sender_email})
      |> subject(subject)
      |> text_body(body)

    case Mailer.deliver(email) do
      {:ok, metadata} ->
        Logger.info("Email sent successfully",
          to: recipient,
          subject: subject,
          metadata: inspect(metadata)
        )
        {:ok, email}
        
      {:error, reason} ->
        Logger.error("Failed to send email",
          to: recipient,
          subject: subject,
          error: inspect(reason)
        )
        {:error, reason}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to confirm a new account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver confirmation that account has been deleted.
  """
  def deliver_account_deletion_confirmation(user) do
    deliver(user.email, "Account deletion confirmation", """

    ==============================

    Hi #{user.email},

    Your account has been successfully deleted. Your data will be permanently removed within 30 days.

    If you did not request this deletion, please contact support immediately.

    ==============================
    """)
  end
end
