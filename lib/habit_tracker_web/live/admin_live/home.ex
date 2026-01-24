defmodule HabitTrackerWeb.AdminLive.Home do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Admin

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Auto-refresh every 60 seconds
      Process.send_after(self(), :refresh_metrics, 60_000)
    end

    socket = assign(socket, :current_scope, nil)
    {:ok, load_metrics(socket)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_metrics(socket)}
  end

  @impl true
  def handle_info(:refresh_metrics, socket) do
    # Schedule next refresh
    Process.send_after(self(), :refresh_metrics, 60_000)
    {:noreply, load_metrics(socket)}
  end

  defp load_metrics(socket) do
    metrics = Admin.system_metrics()

    socket
    |> assign(:metrics, metrics)
    |> assign(:last_updated, DateTime.utc_now())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">
              Admin Dashboard
            </h1>
            <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
              System metrics and analytics
            </p>
          </div>
          <div class="flex items-center gap-4">
            <span class="text-sm text-gray-500 dark:text-gray-400">
              Last updated: <%= format_time(@last_updated) %>
            </span>
            <button
              phx-click="refresh"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" />
              Refresh
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <%!-- User Metrics --%>
          <.metric_card
            title="Total Users"
            value={@metrics.total_users}
            icon="hero-users"
            color="blue"
          />

          <.metric_card
            title="New Users Today"
            value={@metrics.new_users_today}
            icon="hero-user-plus"
            color="green"
          />

          <.metric_card
            title="Daily Active Users"
            value={@metrics.dau}
            icon="hero-chart-bar"
            color="purple"
          />

          <.metric_card
            title="Weekly Active Users"
            value={@metrics.wau}
            icon="hero-chart-bar"
            color="purple"
          />

          <.metric_card
            title="Monthly Active Users"
            value={@metrics.mau}
            icon="hero-chart-bar"
            color="purple"
          />

          <%!-- Habit Metrics --%>
          <.metric_card
            title="Total Habits"
            value={@metrics.total_habits}
            icon="hero-clipboard-document-list"
            color="indigo"
          />

          <.metric_card
            title="Active Habits"
            value={@metrics.active_habits}
            icon="hero-clipboard-document-check"
            color="green"
          />

          <.metric_card
            title="Completions Today"
            value={@metrics.completions_today}
            icon="hero-check-circle"
            color="green"
          />

          <.metric_card
            title="Avg Completion Rate"
            value={"#{Float.round(@metrics.avg_completion_rate * 100, 1)}%"}
            icon="hero-chart-pie"
            color="amber"
          />
        </div>

        <div class="mt-8 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400" />
            </div>
            <div class="ml-3">
              <p class="text-sm text-blue-700 dark:text-blue-300">
                Metrics are automatically refreshed every 60 seconds. Click the refresh button to update manually.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp metric_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg border border-gray-200 dark:border-gray-700">
      <div class="p-5">
        <div class="flex items-center">
          <div class={"flex-shrink-0 rounded-md p-3 #{metric_color_class(@color)}"}>
            <.icon name={@icon} class="h-6 w-6 text-white" />
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
                <%= @title %>
              </dt>
              <dd class="flex items-baseline">
                <div class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
                  <%= @value %>
                </div>
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp metric_color_class("blue"), do: "bg-blue-500"
  defp metric_color_class("green"), do: "bg-green-500"
  defp metric_color_class("purple"), do: "bg-purple-500"
  defp metric_color_class("indigo"), do: "bg-indigo-500"
  defp metric_color_class("amber"), do: "bg-amber-500"
  defp metric_color_class(_), do: "bg-gray-500"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end
end
