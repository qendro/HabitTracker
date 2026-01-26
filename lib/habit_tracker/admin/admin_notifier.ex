defmodule HabitTracker.Admin.AdminNotifier do
  import Swoosh.Email

  alias HabitTracker.Mailer

  require Logger

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
  Deliver instructions to reset an admin password.
  """
  def deliver_reset_password_instructions(admin, url) do
    deliver(admin.email, "Admin reset password instructions", """

    ==============================

    Hi #{admin.email},

    You can reset your admin password by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end
end
