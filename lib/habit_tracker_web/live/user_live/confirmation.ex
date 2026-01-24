defmodule HabitTrackerWeb.UserLive.Confirmation do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            <%= cond do %>
              <% @confirmed == true -> %>
                Account confirmed
              <% @confirmed == false -> %>
                Confirmation link invalid
              <% true -> %>
                Confirming your account
            <% end %>
          </.header>
        </div>

        <p :if={@confirmed == true} class="mt-4 text-sm text-slate-600">
          Your account is now active. You can log in with your email and password.
        </p>

        <p :if={@confirmed == false} class="mt-4 text-sm text-slate-600">
          This confirmation link is invalid or has expired. Please request a new one.
        </p>

        <p :if={is_nil(@confirmed)} class="mt-4 text-sm text-slate-600">
          Confirming your account. This should only take a moment.
        </p>

        <div class="mt-6">
          <.button navigate={~p"/users/log-in"} class="w-full">
            Go to log in
          </.button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if connected?(socket) do
      confirmed =
        case Accounts.confirm_user(token) do
          {:ok, _user} -> true
          {:error, _} -> false
        end

      {:ok, assign(socket, confirmed: confirmed)}
    else
      {:ok, assign(socket, confirmed: nil)}
    end
  end
end
