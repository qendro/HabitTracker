defmodule HabitTrackerWeb.UserLive.Login do
  use HabitTrackerWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 flex items-center justify-center px-4 py-12">
      <div class="max-w-md w-full space-y-8">
        <%!-- Logo/Header --%>
        <div class="text-center">
          <div class="mx-auto h-16 w-16 bg-indigo-600 rounded-2xl flex items-center justify-center mb-4">
            <span class="text-3xl">✅</span>
          </div>
          <h2 class="text-3xl font-bold text-gray-900 dark:text-white">
            Welcome back
          </h2>
          <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Don't have an account?
              <.link navigate={~p"/users/register"} class="font-semibold text-indigo-600 hover:text-indigo-500 dark:text-indigo-400">
                Sign up for free
              </.link>
            <% end %>
          </p>
        </div>

        <%!-- Dev Mail Adapter Notice --%>
        <div :if={local_mail_adapter?()} class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400 mr-3 flex-shrink-0" />
            <div class="text-sm text-blue-700 dark:text-blue-300">
              <p class="font-medium">Development Mode</p>
              <p class="mt-1">
                To see sent emails, visit <.link href="/dev/mailbox" class="underline font-medium">the mailbox page</.link>.
              </p>
            </div>
          </div>
        </div>

        <%!-- Login Form --%>
        <div class="bg-white dark:bg-gray-800 shadow-xl rounded-2xl p-8">
          <.form
            for={@form}
            id="login_form"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-6"
          >
            <div>
              <label for="login_form_email" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Email address
              </label>
              <input
                readonly={!!@current_scope}
                id="login_form_email"
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
              <label for="login_form_password" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Password
              </label>
              <input
                id="login_form_password"
                name="user[password]"
                type="password"
                value={@form[:password].value}
                autocomplete="current-password"
                required
                class="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-colors"
                placeholder="••••••••"
                style="font-size: 16px;"
              />
            </div>

            <div class="flex items-center justify-between">
              <div class="text-sm">
                <.link navigate={~p"/users/reset-password"} class="font-medium text-indigo-600 hover:text-indigo-500 dark:text-indigo-400">
                  Forgot your password?
                </.link>
              </div>
            </div>

            <div class="space-y-3">
              <button
                type="submit"
                name={@form[:remember_me].name}
                value="true"
                class="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
              >
                Sign in and remember me
              </button>
              <button
                type="submit"
                class="w-full flex justify-center py-3 px-4 border border-gray-300 dark:border-gray-600 rounded-lg shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
              >
                Sign in for this session only
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  defp local_mail_adapter? do
    Application.get_env(:habit_tracker, HabitTracker.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
