defmodule HabitTrackerWeb.UserLive.Confirmation do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-cyan-50 flex items-center justify-center px-4 py-12">
      <div class="max-w-md w-full space-y-8">
        <%!-- Logo/Header --%>
        <div class="text-center">
          <div class="mx-auto w-16 h-16 bg-gradient-to-br from-blue-600 to-cyan-600 rounded-xl flex items-center justify-center mb-4 shadow-lg">
            <%= if @confirmed == true do %>
              <.icon name="hero-check-circle" class="w-10 h-10 text-white" />
            <% else %>
              <.icon name="hero-envelope" class="w-8 h-8 text-white" />
            <% end %>
          </div>
          <h2 class="text-4xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-3">
            <%= cond do %>
              <% @confirmed == true -> %>
                Account confirmed!
              <% @confirmed == false -> %>
                Confirmation link invalid
              <% true -> %>
                Confirming your account
            <% end %>
          </h2>
        </div>

        <%!-- Status Card --%>
        <div class="bg-white/80 backdrop-blur-lg shadow-2xl rounded-3xl p-8 border border-gray-100">
          <div class="text-center">
            <%= cond do %>
              <% @confirmed == true -> %>
                <div class="mb-6">
                  <div class="mx-auto w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mb-4">
                    <.icon name="hero-check" class="w-12 h-12 text-green-600" />
                  </div>
                  <p class="text-base text-gray-700">
                    Your account is now active. You can log in with your email and password.
                  </p>
                </div>
              <% @confirmed == false -> %>
                <div class="mb-6">
                  <div class="mx-auto w-20 h-20 bg-red-100 rounded-full flex items-center justify-center mb-4">
                    <.icon name="hero-x-mark" class="w-12 h-12 text-red-600" />
                  </div>
                  <p class="text-base text-gray-700">
                    This confirmation link is invalid or has expired. Please request a new one.
                  </p>
                </div>
              <% true -> %>
                <div class="mb-6">
                  <div class="mx-auto w-20 h-20 bg-blue-100 rounded-full flex items-center justify-center mb-4">
                    <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
                  </div>
                  <p class="text-base text-gray-700">
                    Confirming your account. This should only take a moment.
                  </p>
                </div>
            <% end %>

            <.button navigate={~p"/users/log-in"} class="w-full">
              Go to log in
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if connected?(socket) do
      case Accounts.confirm_user(token) do
        {:ok, _user} ->
          {:ok,
           socket
           |> put_flash(:info, "Account confirmed. Please sign in.")
           |> push_navigate(to: ~p"/users/log-in")}

        {:error, _} ->
          {:ok, assign(socket, confirmed: false)}
      end
    else
      {:ok, assign(socket, confirmed: nil)}
    end
  end
end
