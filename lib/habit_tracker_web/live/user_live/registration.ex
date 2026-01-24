defmodule HabitTrackerWeb.UserLive.Registration do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts
  alias HabitTrackerWeb.RateLimiter
  alias HabitTracker.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-cyan-50 flex items-center justify-center px-4 py-12">
      <div class="max-w-md w-full space-y-8">
        <%!-- Logo/Header --%>
        <div class="text-center">
          <div class="mx-auto w-16 h-16 bg-gradient-to-br from-blue-600 to-cyan-600 rounded-xl flex items-center justify-center mb-4 shadow-lg">
            <span class="text-white text-3xl font-bold">H</span>
          </div>
          <h2 class="text-4xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-3">
            Create your account
          </h2>
          <p class="text-base text-gray-600">
            Already have an account?
            <.link navigate={~p"/users/log-in"} class="font-semibold text-blue-600 hover:text-cyan-600 transition-colors">
              Sign in
            </.link>
          </p>
        </div>

        <%!-- Registration Form --%>
        <div class="bg-white/80 backdrop-blur-lg shadow-2xl rounded-3xl p-8 border border-gray-100">
          <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate" class="space-y-6">
            <div>
              <label for="registration_form_email" class="block text-sm font-semibold text-gray-900 mb-2">
                Email address
              </label>
              <input
                id="registration_form_email"
                name="user[email]"
                type="email"
                value={@form[:email].value}
                autocomplete="username"
                required
                phx-mounted={JS.focus()}
                class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:ring-4 focus:ring-blue-200 focus:border-blue-500 transition-all"
                placeholder="you@example.com"
                style="font-size: 16px;"
              />
            </div>

            <div>
              <label for="registration_form_password" class="block text-sm font-semibold text-gray-900 mb-2">
                Password
              </label>
              <input
                id="registration_form_password"
                name="user[password]"
                type="password"
                value={@form[:password].value}
                autocomplete="new-password"
                required
                class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:ring-4 focus:ring-blue-200 focus:border-blue-500 transition-all"
                placeholder="••••••••"
                style="font-size: 16px;"
              />
              <p class="mt-2 text-xs text-gray-500">
                Must be at least 8 characters long
              </p>
            </div>

            <input
              field={@form[:timezone]}
              type="hidden"
              id="registration-timezone"
              name="user[timezone]"
              value={@form[:timezone].value}
              phx-hook="TimezoneDetect"
            />

            <div>
              <button
                type="submit"
                phx-disable-with="Creating account..."
                class="w-full flex justify-center py-4 px-4 border border-transparent rounded-xl shadow-lg text-base font-semibold text-white bg-gradient-to-r from-blue-600 to-cyan-600 hover:opacity-90 transition-all transform hover:scale-105"
              >
                Create account
              </button>
            </div>

            <p class="text-xs text-center text-gray-500">
              By creating an account, you agree to our Terms of Service and Privacy Policy
            </p>
          </.form>
        </div>

        <%!-- Features --%>
        <div class="bg-white/80 backdrop-blur-lg shadow-xl rounded-3xl p-6 border border-gray-100">
          <h3 class="text-sm font-bold text-gray-900 mb-4">
            What you'll get:
          </h3>
          <ul class="space-y-3">
            <li class="flex items-start">
              <.icon name="hero-check-circle" class="h-5 w-5 text-emerald-500 mr-3 flex-shrink-0 mt-0.5" />
              <span class="text-sm text-gray-600">Track unlimited habits</span>
            </li>
            <li class="flex items-start">
              <.icon name="hero-check-circle" class="h-5 w-5 text-emerald-500 mr-3 flex-shrink-0 mt-0.5" />
              <span class="text-sm text-gray-600">View your progress and streaks</span>
            </li>
            <li class="flex items-start">
              <.icon name="hero-check-circle" class="h-5 w-5 text-emerald-500 mr-3 flex-shrink-0 mt-0.5" />
              <span class="text-sm text-gray-600">Daily email reminders</span>
            </li>
            <li class="flex items-start">
              <.icon name="hero-check-circle" class="h-5 w-5 text-emerald-500 mr-3 flex-shrink-0 mt-0.5" />
              <span class="text-sm text-gray-600">Customizable themes and settings</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: HabitTrackerWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset =
      Accounts.change_user_registration(%User{}, %{},
        validate_unique: false,
        hash_password: false
      )

    socket =
      socket
      |> assign_form(changeset)
      |> assign(:client_ip, get_client_ip(socket))

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case RateLimiter.check_registration(socket.assigns.client_ip) do
      :deny ->
        {:noreply,
         socket
         |> put_flash(:error, "Too many registration attempts. Please try again later.")
         |> push_navigate(to: ~p"/users/register")}

      :allow ->
        case Accounts.register_user(user_params) do
          {:ok, user} ->
            {:ok, _} =
              Accounts.deliver_user_confirmation_instructions(
                user,
                &url(~p"/users/confirm/#{&1}")
              )

            {:noreply,
             socket
             |> put_flash(
               :info,
               "Account created! Please check #{user.email} for a confirmation link to activate your account."
             )
             |> push_navigate(to: ~p"/users/log-in")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_form(socket, changeset)}
        end
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_registration(%User{}, user_params,
        validate_unique: false,
        hash_password: false
      )

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end

  defp get_client_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} -> address |> :inet.ntoa() |> to_string()
      _ -> nil
    end
  end
end
