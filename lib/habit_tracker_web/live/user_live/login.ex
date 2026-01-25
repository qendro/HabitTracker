defmodule HabitTrackerWeb.UserLive.Login do
  use HabitTrackerWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-cyan-50 flex items-center justify-center px-4 py-12">
      <div class="max-w-md w-full space-y-8">
        <Layouts.flash_group flash={@flash} />
        <%!-- Logo/Header --%>
        <div class="text-center">
          <div class="mx-auto w-16 h-16 bg-gradient-to-br from-blue-600 to-cyan-600 rounded-xl flex items-center justify-center mb-4 shadow-lg">
            <span class="text-white text-3xl font-bold">H</span>
          </div>
          <h2 class="text-4xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-3">
            Welcome back
          </h2>
          <p class="text-base text-gray-600">
            <%= if @current_scope do %>
              You need to reauthenticate to perform sensitive actions on your account.
            <% else %>
              Don't have an account?
              <.link navigate={~p"/users/register"} class="font-semibold text-blue-600 hover:text-cyan-600 transition-colors">
                Sign up for free
              </.link>
            <% end %>
          </p>
        </div>

        <%!-- Dev Mail Adapter Notice --%>
        <div :if={local_mail_adapter?()} class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400 mr-3 flex-shrink-0" />
            <div class="text-sm text-blue-700">
              <p class="font-medium">Development Mode</p>
              <p class="mt-1">
                To see sent emails, visit <.link href="/dev/mailbox" class="underline font-medium">the mailbox page</.link>.
              </p>
            </div>
          </div>
        </div>

        <%!-- Login Form --%>
        <div class="bg-white/80 backdrop-blur-lg shadow-2xl rounded-3xl p-8 border border-gray-100">
          <.form
            for={@form}
            id="login_form"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-6"
          >
            <div>
              <label for="login_form_email" class="block text-sm font-semibold text-gray-900 mb-2">
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
                class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:ring-4 focus:ring-blue-200 focus:border-blue-500 transition-all"
                placeholder="you@example.com"
                style="font-size: 16px;"
              />
            </div>

            <div>
              <label for="login_form_password" class="block text-sm font-semibold text-gray-900 mb-2">
                Password
              </label>
              <input
                id="login_form_password"
                name="user[password]"
                type="password"
                value={@form[:password].value}
                autocomplete="current-password"
                required
                class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:ring-4 focus:ring-blue-200 focus:border-blue-500 transition-all"
                placeholder="••••••••"
                style="font-size: 16px;"
              />
            </div>

            <div class="flex items-center justify-between">
              <div class="text-sm">
                <.link navigate={~p"/users/reset-password"} class="font-semibold text-blue-600 hover:text-cyan-600 transition-colors">
                  Forgot your password?
                </.link>
              </div>
            </div>

            <div class="space-y-3">
              <button
                type="submit"
                name={@form[:remember_me].name}
                value="true"
                class="w-full flex justify-center py-4 px-4 border border-transparent rounded-xl shadow-lg text-base font-semibold text-white bg-gradient-to-r from-blue-600 to-cyan-600 hover:opacity-90 transition-all transform hover:scale-105"
              >
                Sign in and remember me
              </button>
              <button
                type="submit"
                class="w-full flex justify-center py-4 px-4 border-2 border-gray-200 rounded-xl shadow-md text-base font-semibold text-gray-900 bg-white hover:border-blue-600 transition-all"
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
