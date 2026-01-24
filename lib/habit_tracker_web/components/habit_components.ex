defmodule HabitTrackerWeb.HabitComponents do
  @moduledoc """
  Reusable habit-related UI components.
  """
  use Phoenix.Component
  import HabitTrackerWeb.CoreComponents

  @doc """
  Renders a habit card with progress, streak, and action buttons.

  ## Examples

      <.habit_card
        habit={@habit}
        log={@log}
        streak={5}
        is_complete={true}
        progress={%{type: :binary, status: :complete}}
        is_future={false}
      />
  """
  attr :habit, :map, required: true
  attr :log, :map, default: nil
  attr :streak, :integer, required: true
  attr :is_complete, :boolean, required: true
  attr :progress, :map, required: true
  attr :is_future, :boolean, default: false
  attr :readonly, :boolean, default: false

  def habit_card(assigns) do
    ~H"""
    <div id={"habit-card-#{@habit.id}"} class="habit-card fade-in">
      <div class="flex items-start justify-between">
        <div class="flex items-start space-x-3 flex-1">
          <%!-- Icon --%>
          <div
            class="habit-icon"
            style={"background-color: #{@habit.color}20; color: #{@habit.color}"}
          >
            <%= @habit.icon %>
          </div>

          <%!-- Habit Info --%>
          <div class="flex-1 min-w-0">
            <h3 class="habit-name">
              <%= @habit.name %>
            </h3>
            <p :if={@habit.description} class="text-sm text-gray-600 dark:text-gray-400 mt-1">
              <%= @habit.description %>
            </p>

            <%!-- Progress --%>
            <div class="mt-3">
              <%= case @progress.type do %>
                <% :binary -> %>
                  <span class={[
                    "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                    status_color(@progress.status)
                  ]}>
                    <%= status_label(@progress.status) %>
                  </span>
                <% :numeric -> %>
                  <div class="space-y-1">
                    <div class="flex items-center justify-between text-sm">
                      <span class="text-gray-600 dark:text-gray-400">
                        <%= @progress.current %> / <%= @progress.target %>
                        <%= if @progress.unit, do: @progress.unit %>
                      </span>
                      <span class="font-medium text-gray-900 dark:text-white">
                        <%= @progress.percentage %>%
                      </span>
                    </div>
                    <div class="progress-bar">
                      <div
                        class="progress-fill"
                        style={"width: #{min(@progress.percentage, 100)}%"}
                      >
                      </div>
                    </div>
                  </div>
                <% :duration -> %>
                  <div class="space-y-1">
                    <div class="flex items-center justify-between text-sm">
                      <span class="text-gray-600 dark:text-gray-400">
                        <%= @progress.current %> / <%= @progress.target %> <%= @progress.unit %>
                      </span>
                      <span class="font-medium text-gray-900 dark:text-white">
                        <%= @progress.percentage %>%
                      </span>
                    </div>
                    <div class="progress-bar">
                      <div
                        class="h-full bg-purple-500 transition-all duration-300"
                        style={"width: #{min(@progress.percentage, 100)}%"}
                      >
                      </div>
                    </div>
                  </div>
              <% end %>
            </div>

            <%!-- Streak Badge --%>
            <div class="mt-3 flex items-center space-x-2">
              <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium bg-orange-100 text-orange-800 dark:bg-orange-900/20 dark:text-orange-400">
                🔥 <%= @streak %> day streak
              </span>
              <span :if={@is_future} class="text-xs text-gray-500 dark:text-gray-400">
                (as of today)
              </span>
            </div>
          </div>
        </div>

        <%!-- Action Buttons --%>
        <div class="ml-4 flex flex-col space-y-2">
          <%!-- Binary habit toggle button --%>
          <button
            :if={@habit.type == :binary && !@readonly}
            phx-click="toggle_habit"
            phx-value-habit-id={@habit.id}
            class={[
              "touch-target rounded-full transition-all duration-200",
              if(@is_complete,
                do: "bg-green-500 hover:bg-green-600 text-white",
                else: "bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600"
              )
            ]}
            aria-label={if @is_complete, do: "Mark as incomplete", else: "Mark as complete"}
          >
            <.icon
              name={if @is_complete, do: "hero-check", else: "hero-check"}
              class="w-6 h-6"
            />
          </button>

          <%!-- Read-only indicator for binary habits --%>
          <div
            :if={@habit.type == :binary && @readonly}
            class={[
              "touch-target rounded-full",
              if(@is_complete,
                do: "bg-green-500 text-white",
                else: "bg-gray-200 dark:bg-gray-700"
              )
            ]}
            aria-label="Read-only mode"
          >
            <.icon name="hero-check" class="w-6 h-6" />
          </div>

          <%!-- Numeric/Duration habit input --%>
          <form
            :if={@habit.type in [:numeric, :duration] && !@readonly}
            phx-submit="log_value"
            class="flex items-center space-x-2"
          >
            <input
              type="number"
              name="value"
              step={if @habit.type == :numeric, do: "0.01", else: "1"}
              min="0"
              value={get_current_value(@log, @habit.type)}
              placeholder={get_placeholder(@habit.type, @habit.unit_label)}
              class="w-24 px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              style="font-size: 16px;"
            />
            <input type="hidden" name="habit-id" value={@habit.id} />
            <button
              type="submit"
              class="touch-target rounded-lg bg-blue-500 hover:bg-blue-600 text-white transition-colors"
              aria-label="Log value"
            >
              <.icon name="hero-check" class="w-5 h-5" />
            </button>
          </form>

          <%!-- Read-only display for numeric/duration habits --%>
          <div
            :if={@habit.type in [:numeric, :duration] && @readonly}
            class="flex items-center space-x-2"
          >
            <input
              type="number"
              value={get_current_value(@log, @habit.type)}
              disabled
              class="w-24 px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400"
              style="font-size: 16px;"
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a completion summary with progress ring.

  ## Examples

      <.completion_summary completed={5} total={10} />
  """
  attr :completed, :integer, required: true
  attr :total, :integer, required: true

  def completion_summary(assigns) do
    assigns = assign(assigns, :percentage, calculate_percentage(assigns.completed, assigns.total))
    assigns = assign(assigns, :all_complete, assigns.completed == assigns.total && assigns.total > 0)

    ~H"""
    <div class="completion-summary">
      <div class="summary-content">
        <span class="summary-count">
          <%= @completed %> / <%= @total %>
        </span>
        <span class="summary-label">complete</span>
      </div>

      <%= if @all_complete do %>
        <div class="celebration">
          🎉
        </div>
      <% end %>

      <div class="relative w-20 h-20">
        <svg class="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
          <%!-- Background circle --%>
          <circle
            cx="50"
            cy="50"
            r="40"
            stroke="currentColor"
            stroke-width="8"
            fill="none"
            class="text-gray-200 dark:text-gray-700"
          />
          <%!-- Progress circle --%>
          <circle
            cx="50"
            cy="50"
            r="40"
            stroke="currentColor"
            stroke-width="8"
            fill="none"
            class="text-indigo-500 transition-all duration-500"
            stroke-dasharray={circumference()}
            stroke-dashoffset={circumference() * (1 - @percentage / 100)}
            stroke-linecap="round"
          />
        </svg>
        <div class="absolute inset-0 flex items-center justify-center">
          <span class="text-lg font-bold text-gray-900 dark:text-white">
            <%= round(@percentage) %>%
          </span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a date navigator with prev/next buttons and date picker.

  ## Examples

      <.date_navigator
        selected_date={~D[2024-01-15]}
        is_today={false}
        timezone="America/New_York"
      />
  """
  attr :selected_date, :any, required: true
  attr :is_today, :boolean, required: true
  attr :timezone, :string, required: true

  def date_navigator(assigns) do
    ~H"""
    <div class="date-navigator">
      <button
        phx-click="prev_day"
        class="nav-button"
        aria-label="Previous day"
      >
        <.icon name="hero-chevron-left" class="w-6 h-6" />
      </button>

      <div class="flex-1 text-center">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          <%= format_date(@selected_date, @is_today) %>
        </h1>
        <p :if={!@is_today} class="text-sm text-gray-600 dark:text-gray-400 mt-1">
          <%= Calendar.strftime(@selected_date, "%A, %B %d, %Y") %>
        </p>
        <%!-- Calendar Picker --%>
        <div class="mt-2">
          <input
            type="date"
            id="date-picker"
            value={Date.to_iso8601(@selected_date)}
            phx-change="select_date"
            name="date"
            class="px-3 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            style="font-size: 16px;"
          />
        </div>
      </div>

      <button
        phx-click="next_day"
        class="nav-button"
        aria-label="Next day"
      >
        <.icon name="hero-chevron-right" class="w-6 h-6" />
      </button>
    </div>

    <%!-- Back to Today Button --%>
    <div :if={!@is_today} class="text-center mt-4">
      <button
        phx-click="back_to_today"
        class="today-button"
      >
        Back to Today
      </button>
    </div>
    """
  end

  # Helper functions

  defp status_color(:complete), do: "bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400"
  defp status_color(:planned), do: "bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400"
  defp status_color(:not_complete), do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-400"

  defp status_label(:complete), do: "Complete"
  defp status_label(:planned), do: "Planned"
  defp status_label(:not_complete), do: "Not Complete"

  defp get_current_value(nil, _type), do: ""
  defp get_current_value(log, :numeric) do
    cond do
      is_nil(log.numeric_value) -> ""
      is_integer(log.numeric_value) -> to_string(log.numeric_value)
      true -> Decimal.to_string(log.numeric_value)
    end
  end
  defp get_current_value(log, :duration), do: if(log.duration_minutes, do: to_string(log.duration_minutes), else: "")
  defp get_current_value(_log, _type), do: ""

  defp get_placeholder(:numeric, unit_label) when is_binary(unit_label), do: "Enter #{unit_label}"
  defp get_placeholder(:numeric, _), do: "Enter value"
  defp get_placeholder(:duration, _), do: "Minutes"
  defp get_placeholder(_type, _), do: ""

  defp format_date(_date, true), do: "Today"
  defp format_date(date, false), do: Calendar.strftime(date, "%b %d")

  defp calculate_percentage(_completed, 0), do: 0
  defp calculate_percentage(completed, total), do: completed / total * 100

  defp circumference, do: 2 * :math.pi() * 40
end
