defmodule HabitTrackerWeb.UserLive.ResetPassword do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts
  alias HabitTracker.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 flex items-center justify-center px-4 py-12">
      <div class="max-w-md w-full space-y-8">
        <%!-- Logo/Header --%>
        <div class="text-center">
          <div class="mx-auto h-16 w-16 bg-indigo-600 rounded-2xl flex items-center justify-center mb-4">
            <.icon name="hero-key" class="w-8 h-8 text-white" />
          </div>
          <h2 class="text-3xl font-bold text-gray-900 dark:text-white">
            Set a new password
          </h2>
          <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
            Create a strong password for your account
          </p>
        </div>

        <%!-- Reset Password Form --%>
        <div class="bg-white dark:bg-gray-800 shadow-xl rounded-2xl p-8">
          <.form
            for={@form}
            id="reset_password_form"
            phx-change="validate"
            phx-submit="reset_password"
            class="space-y-6"
          >
            <div>
              <label for="new_password" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                New password
              </label>
              <input
                id="new_password"
                name="user[password]"
                type="password"
                value={@form[:password].value}
                autocomplete="new-password"
                required
                phx-mounted={JS.focus()}
                class="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-colors"
                placeholder="••••••••"
                style="font-size: 16px;"
              />
              <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">
                Must be at least 8 characters long
              </p>
            </div>

            <div>
              <label for="confirm_password" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Confirm new password
              </label>
              <input
                id="confirm_password"
                name="user[password_confirmation]"
                type="password"
                value={@form[:password_confirmation].value}
                autocomplete="new-password"
                required
                class="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-colors"
                placeholder="••••••••"
                style="font-size: 16px;"
              />
            </div>

            <div>
              <button
                type="submit"
                phx-disable-with="Resetting..."
                class="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
              >
                Reset password
              </button>
            </div>
          </.form>
        </div>

        <%!-- Security Tips --%>
        <div class="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-shield-check" class="h-5 w-5 text-green-400 mr-3 flex-shrink-0" />
            <div class="text-sm text-green-700 dark:text-green-300">
              <p class="font-medium">Password tips:</p>
              <ul class="mt-1 list-disc list-inside space-y-1">
                <li>Use at least 8 characters</li>
                <li>Mix letters, numbers, and symbols</li>
                <li>Avoid common words or patterns</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_reset_password_token(token) do
      %User{} = user ->
        changeset = Accounts.change_user_password(user, %{}, hash_password: false)

        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:token, token)
         |> assign(:form, to_form(changeset))}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Reset link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/reset-password")}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.get_user_by_reset_password_token(socket.assigns.token) do
      %User{} = user ->
        case Accounts.reset_user_password(user, user_params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Password reset successfully.")
             |> push_navigate(to: ~p"/users/log-in")}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Reset link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/reset-password")}
    end
  end
end
