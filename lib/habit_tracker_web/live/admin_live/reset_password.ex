defmodule HabitTrackerWeb.AdminLive.ResetPassword do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Admin
  alias HabitTracker.Admin.Admin

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-cyan-50 flex items-center justify-center px-4 py-12">
      <div class="max-w-md w-full space-y-8">
        <%!-- Logo/Header --%>
        <div class="text-center">
          <div class="mx-auto w-16 h-16 bg-gradient-to-br from-blue-600 to-cyan-600 rounded-xl flex items-center justify-center mb-4 shadow-lg">
            <.icon name="hero-key" class="w-8 h-8 text-white" />
          </div>
          <h2 class="text-4xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-3">
            Set a new admin password
          </h2>
          <p class="text-base text-gray-600">
            Create a strong password for your admin account
          </p>
        </div>

        <%!-- Reset Password Form --%>
        <div class="bg-white/80 backdrop-blur-lg shadow-2xl rounded-3xl p-8 border border-gray-100">
          <.form
            for={@form}
            id="admin_reset_password_form"
            phx-change="validate"
            phx-submit="reset_password"
            class="space-y-6"
          >
            <div>
              <label for="admin_new_password" class="block text-sm font-semibold text-gray-900 mb-2">
                New password
              </label>
              <input
                id="admin_new_password"
                name="admin[password]"
                type="password"
                value={@form[:password].value}
                autocomplete="new-password"
                required
                phx-mounted={JS.focus()}
                class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:ring-4 focus:ring-blue-200 focus:border-blue-500 transition-all"
                placeholder="••••••••"
                style="font-size: 16px;"
              />
              <p class="mt-2 text-xs text-gray-500">
                Must be at least 8 characters long
              </p>
            </div>

            <div>
              <label for="admin_confirm_password" class="block text-sm font-semibold text-gray-900 mb-2">
                Confirm new password
              </label>
              <input
                id="admin_confirm_password"
                name="admin[password_confirmation]"
                type="password"
                value={@form[:password_confirmation].value}
                autocomplete="new-password"
                required
                class="w-full px-4 py-3 border-2 border-gray-200 rounded-xl bg-white text-gray-900 placeholder-gray-400 focus:ring-4 focus:ring-blue-200 focus:border-blue-500 transition-all"
                placeholder="••••••••"
                style="font-size: 16px;"
              />
            </div>

            <div>
              <button
                type="submit"
                phx-disable-with="Resetting..."
                class="w-full flex justify-center py-4 px-4 border border-transparent rounded-xl shadow-lg text-base font-semibold text-white bg-gradient-to-r from-blue-600 to-cyan-600 hover:opacity-90 transition-all transform hover:scale-105"
              >
                Reset password
              </button>
            </div>
          </.form>
        </div>

        <%!-- Security Tips --%>
        <div class="bg-green-50 border border-green-200 rounded-xl p-4">
          <div class="flex">
            <.icon name="hero-shield-check" class="h-5 w-5 text-green-400 mr-3 flex-shrink-0" />
            <div class="text-sm text-green-700">
              <p class="font-semibold">Password tips:</p>
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
    case Admin.get_admin_by_reset_password_token(token) do
      %Admin{} = admin ->
        changeset = Admin.change_admin_password(admin, %{}, hash_password: false)

        {:ok,
         socket
         |> assign(:admin, admin)
         |> assign(:token, token)
         |> assign(:form, to_form(changeset))}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Reset link is invalid or it has expired.")
         |> push_navigate(to: ~p"/admin/reset-password")}
    end
  end

  @impl true
  def handle_event("validate", %{"admin" => admin_params}, socket) do
    changeset =
      socket.assigns.admin
      |> Admin.change_admin_password(admin_params, hash_password: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("reset_password", %{"admin" => admin_params}, socket) do
    case Admin.get_admin_by_reset_password_token(socket.assigns.token) do
      %Admin{} = admin ->
        case Admin.reset_admin_password(admin, admin_params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Password reset successfully.")
             |> push_navigate(to: ~p"/admin/login")}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Reset link is invalid or it has expired.")
         |> push_navigate(to: ~p"/admin/reset-password")}
    end
  end
end
