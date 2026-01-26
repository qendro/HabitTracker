defmodule HabitTrackerWeb.AdminLive.Login do
  use HabitTrackerWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-cyan-50 flex items-center justify-center px-4 py-12">
      <div class="max-w-md w-full space-y-8">
        <Layouts.flash_group flash={@flash} />

        <div class="text-center">
          <div class="mx-auto w-16 h-16 bg-gradient-to-br from-blue-600 to-cyan-600 rounded-xl flex items-center justify-center mb-4 shadow-lg">
            <.icon name="hero-shield-check" class="w-8 h-8 text-white" />
          </div>
          <h2 class="text-4xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-3">
            Admin log in
          </h2>
          <p class="text-base text-gray-600">
            Admin access only. Accounts are provisioned via the CLI.
          </p>
        </div>

        <div class="bg-white/80 backdrop-blur-lg shadow-2xl rounded-3xl p-8 border border-gray-100">
          <.form
            for={@form}
            id="admin_login_form"
            action={~p"/admin/log-in"}
            phx-submit="submit"
            phx-trigger-action={@trigger_submit}
            class="space-y-6"
          >
            <div>
              <label for="admin_login_email" class="block text-sm font-semibold text-gray-900 mb-2">
                Email address
              </label>
              <input
                id="admin_login_email"
                name="admin[email]"
                type="email"
                value={@form[:email].value}
                autocomplete="email"
                required
                phx-mounted={JS.focus()}
                class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:ring-4 focus:ring-blue-200 focus:border-blue-500 transition-all"
                placeholder="admin@example.com"
                style="font-size: 16px;"
              />
            </div>

            <div>
              <label for="admin_login_password" class="block text-sm font-semibold text-gray-900 mb-2">
                Password
              </label>
              <input
                id="admin_login_password"
                name="admin[password]"
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
                <.link navigate={~p"/admin/reset-password"} class="font-semibold text-blue-600 hover:text-cyan-600 transition-colors">
                  Forgot your password?
                </.link>
              </div>
            </div>

            <div>
              <button
                type="submit"
                phx-disable-with="Signing in..."
                class="w-full flex justify-center py-4 px-4 border border-transparent rounded-xl shadow-lg text-base font-semibold text-white bg-gradient-to-r from-blue-600 to-cyan-600 hover:opacity-90 transition-all transform hover:scale-105"
              >
                Sign in
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
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "admin")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
