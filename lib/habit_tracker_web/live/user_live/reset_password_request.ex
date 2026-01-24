defmodule HabitTrackerWeb.UserLive.ResetPasswordRequest do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts
  alias HabitTrackerWeb.RateLimiter

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 flex items-center justify-center px-4 py-12">
      <div class="max-w-md w-full space-y-8">
        <%!-- Logo/Header --%>
        <div class="text-center">
          <div class="mx-auto h-16 w-16 bg-indigo-600 rounded-2xl flex items-center justify-center mb-4">
            <.icon name="hero-lock-closed" class="w-8 h-8 text-white" />
          </div>
          <h2 class="text-3xl font-bold text-gray-900 dark:text-white">
            Reset your password
          </h2>
          <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
            Enter your email address and we'll send you a link to reset your password
          </p>
        </div>

        <%!-- Reset Form --%>
        <div class="bg-white dark:bg-gray-800 shadow-xl rounded-2xl p-8">
          <.form for={@form} id="reset_password_request_form" phx-submit="send" class="space-y-6">
            <div>
              <label for="reset_email" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
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
                class="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-colors"
                placeholder="you@example.com"
                style="font-size: 16px;"
              />
            </div>

            <div>
              <button
                type="submit"
                phx-disable-with="Sending..."
                class="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
              >
                Send reset instructions
              </button>
            </div>
          </.form>

          <div class="mt-6 text-center">
            <.link navigate={~p"/users/log-in"} class="text-sm font-medium text-indigo-600 hover:text-indigo-500 dark:text-indigo-400">
              ← Back to login
            </.link>
          </div>
        </div>

        <%!-- Help Text --%>
        <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400 mr-3 flex-shrink-0" />
            <div class="text-sm text-blue-700 dark:text-blue-300">
              <p class="font-medium">What happens next?</p>
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
