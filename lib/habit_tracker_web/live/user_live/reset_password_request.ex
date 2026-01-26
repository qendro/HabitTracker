defmodule HabitTrackerWeb.UserLive.ResetPasswordRequest do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts
  alias HabitTrackerWeb.RateLimiter

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-cyan-50 flex items-center justify-center px-4 py-12">
      <div class="max-w-md w-full space-y-8">
        <%!-- Logo/Header --%>
        <div class="text-center">
          <div class="mx-auto w-16 h-16 bg-gradient-to-br from-blue-600 to-cyan-600 rounded-xl flex items-center justify-center mb-4 shadow-lg">
            <.icon name="hero-lock-closed" class="w-8 h-8 text-white" />
          </div>
          <h2 class="text-4xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-3">
            Reset your password
          </h2>
          <p class="text-base text-gray-600">
            Enter your email address and we'll send you a link to reset your password
          </p>
        </div>

        <%!-- Reset Form --%>
        <div class="bg-white/80 backdrop-blur-lg shadow-2xl rounded-3xl p-8 border border-gray-100">
          <.form for={@form} id="reset_password_request_form" phx-submit="send" class="space-y-6">
            <div>
              <label for="reset_email" class="block text-sm font-semibold text-gray-900 mb-2">
                Email address
              </label>
              <input
                id="reset_email"
                name="user[email]"
                type="email"
                value={@form[:email].value}
                autocomplete="email"
                required
                phx-mounted={JS.focus()}
                class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:ring-4 focus:ring-blue-200 focus:border-blue-500 transition-all"
                placeholder="you@example.com"
                style="font-size: 16px;"
              />
            </div>

            <div>
              <button
                type="submit"
                phx-disable-with="Sending..."
                class="w-full flex justify-center py-4 px-4 border border-transparent rounded-xl shadow-lg text-base font-semibold text-white bg-gradient-to-r from-blue-600 to-cyan-600 hover:opacity-90 transition-all transform hover:scale-105"
              >
                Send reset instructions
              </button>
            </div>
          </.form>

          <div class="mt-6 text-center">
            <.link navigate={~p"/users/log-in"} class="text-sm font-semibold text-blue-600 hover:text-cyan-600 transition-colors">
              ← Back to login
            </.link>
          </div>
        </div>

        <%!-- Help Text --%>
        <div class="bg-blue-50 border border-blue-200 rounded-xl p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400 mr-3 flex-shrink-0" />
            <div class="text-sm text-blue-700">
              <p class="font-semibold">What happens next?</p>
              <p class="mt-1">
                If your email is in our system, you'll receive a password reset link within a few minutes.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
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
