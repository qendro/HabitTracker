defmodule HabitTrackerWeb.UserLive.ResetPasswordRequest do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts
  alias HabitTrackerWeb.RateLimiter

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Reset your password
            <:subtitle>Enter your email to receive a reset link.</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="reset_password_request_form" phx-submit="send">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="email"
            required
            phx-mounted={JS.focus()}
          />

          <.button phx-disable-with="Sending..." class="w-full">
            Send reset instructions
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"email" => ""}, as: "user"))}
  end

  @impl true
  def handle_event("send", %{"user" => %{"email" => email}}, socket) do
    case RateLimiter.check_password_reset(email) do
      :deny ->
        {:noreply,
         socket
         |> put_flash(:error, "Too many reset attempts. Please try again later.")
         |> push_navigate(to: ~p"/users/reset-password")}

      :allow ->
        if user = Accounts.get_user_by_email(email) do
          Accounts.deliver_user_reset_password_instructions(
            user,
            &url(~p"/users/reset-password/#{&1}")
          )
        end

        info = "If your email is in our system, you will receive reset instructions shortly."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> push_navigate(to: ~p"/users/log-in")}
    end
  end
end
