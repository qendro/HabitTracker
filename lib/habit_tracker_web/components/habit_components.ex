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
    <div id={"habit-card-#{@habit.id}"} class="habit-card-glass">
      <div class="flex items-start justify-between gap-4">
        <div class="flex items-start space-x-4 flex-1 min-w-0">
          <%!-- Icon --%>
          <div
            class="habit-icon-enhanced"
            style={"background: linear-gradient(135deg, #{@habit.color}20 0%, #{@habit.color}40 100%); color: #{@habit.color}; border: 2px solid #{@habit.color}30;"}
          >
            <%= @habit.icon %>
          </div>

          <%!-- Habit Info --%>
          <div class="flex-1 min-w-0">
            <h3 class="habit-name">
              <%= @habit.name %>
            </h3>
            <p :if={@habit.description} class="habit-description">
              <%= @habit.description %>
            </p>

            <%!-- Progress --%>
            <div class="mt-4">
              <%= case @progress.type do %>
                <% :binary -> %>
                  <span class={[
                    "badge",
                    case @progress.status do
                      :complete -> "badge-success"
                      :planned -> "badge-info"
                      :not_complete -> "badge-neutral"
                    end
                  ]}>
                    <%= case @progress.status do %>
                      <% :complete -> %>
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                        </svg>
                      <% :planned -> %>
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
                        </svg>
                      <% :not_complete -> %>
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                        </svg>
                    <% end %>
                    <%= status_label(@progress.status) %>
                  </span>
                <% :numeric -> %>
                  <div class="space-y-2">
                    <div class="flex items-center justify-between text-sm font-medium">
                      <span class="text-gray-700 dark:text-gray-300">
                        <%= @progress.current %> / <%= @progress.target %>
                        <%= if @progress.unit, do: @progress.unit %>
                      </span>
                      <span class={[
                        "font-bold",
                        if(@progress.percentage >= 100, do: "text-green-600 dark:text-green-400", else: "text-indigo-600 dark:text-indigo-400")
                      ]}>
                        <%= @progress.percentage %>%
                      </span>
                    </div>
                    <div class="progress-bar-enhanced">
                      <div
                        class="progress-fill-enhanced"
                        style={"width: #{min(@progress.percentage, 100)}%"}
                      >
                      </div>
                    </div>
                  </div>
                <% :duration -> %>
                  <div class="space-y-2">
                    <div class="flex items-center justify-between text-sm font-medium">
                      <span class="text-gray-700 dark:text-gray-300">
                        <%= @progress.current %> / <%= @progress.target %> <%= @progress.unit %>
                      </span>
                      <span class={[
                        "font-bold",
                        if(@progress.percentage >= 100, do: "text-green-600 dark:text-green-400", else: "text-purple-600 dark:text-purple-400")
                      ]}>
                        <%= @progress.percentage %>%
                      </span>
                    </div>
                    <div class="progress-bar-enhanced">
                      <div
                        class="h-full rounded-full bg-gradient-to-r from-purple-500 to-pink-500 transition-all duration-500"
                        style={"width: #{min(@progress.percentage, 100)}%"}
                      >
                      </div>
                    </div>
                  </div>
              <% end %>
            </div>

            <%!-- Streak Badge --%>
            <div class="mt-4 flex items-center gap-2 flex-wrap">
              <span class="streak-badge-enhanced">
                <span class="relative z-10">🔥 <%= @streak %> day streak</span>
              </span>
              <span :if={@is_future} class="text-xs text-gray-500 dark:text-gray-400 italic">
                (as of today)
              </span>
            </div>
          </div>
        </div>

        <%!-- Action Buttons --%>
        <div class="flex flex-col items-center gap-3">
          <%!-- Binary habit toggle button --%>
          <button
            :if={@habit.type == :binary && !@readonly}
            phx-click="toggle_habit"
            phx-value-habit-id={@habit.id}
            class={[
              "toggle-enhanced ripple",
              if(@is_complete, do: "complete", else: "incomplete")
            ]}
            aria-label={if @is_complete, do: "Mark as incomplete", else: "Mark as complete"}
          >
            <svg class="w-7 h-7" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
          </button>

          <%!-- Read-only indicator for binary habits --%>
          <div
            :if={@habit.type == :binary && @readonly}
            class={[
              "toggle-enhanced",
              if(@is_complete, do: "complete", else: "incomplete")
            ]}
            aria-label="Read-only mode"
          >
            <svg class="w-7 h-7" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
          </div>

          <%!-- Numeric/Duration habit input --%>
          <form
            :if={@habit.type in [:numeric, :duration] && !@readonly}
            phx-submit="log_value"
            class="flex flex-col items-center gap-2"
          >
            <input
              type="number"
              name="value"
              step={if @habit.type == :numeric, do: "0.01", else: "1"}
              min="0"
              value={get_current_value(@log, @habit.type)}
              placeholder={get_placeholder(@habit.type, @habit.unit_label)}
              class="w-24 px-3 py-2 text-sm border-2 border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all"
              style="font-size: 16px;"
            />
            <input type="hidden" name="habit-id" value={@habit.id} />
            <button
              type="submit"
              class="toggle-enhanced bg-gradient-to-br from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 text-white ripple"
              aria-label="Log value"
            >
              <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
              </svg>
            </button>
          </form>

          <%!-- Read-only display for numeric/duration habits --%>
          <div
            :if={@habit.type in [:numeric, :duration] && @readonly}
            class="flex flex-col items-center gap-2"
          >
            <input
              type="number"
              value={get_current_value(@log, @habit.type)}
              disabled
              class="w-24 px-3 py-2 text-sm border-2 border-gray-300 dark:border-gray-600 rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400"
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
    assigns = assign(assigns, :motivational_message, get_motivational_message(assigns.completed, assigns.total))

    ~H"""
    <div class={[
      "completion-summary-enhanced",
      if(@all_complete, do: "all-complete", else: "")
    ]}>
      <div class="summary-content relative z-10">
        <span class="summary-count animated-counter">
          <%= @completed %> / <%= @total %>
        </span>
        <span class="summary-label">habits complete</span>
        <p :if={@motivational_message} class="summary-motivational">
          <%= @motivational_message %>
        </p>
      </div>

      <%= if @all_complete do %>
        <div class="celebration">
          🎉
        </div>
      <% end %>

      <div class="relative w-28 h-28">
        <svg class="w-full h-full transform -rotate-90 progress-ring" viewBox="0 0 100 100">
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
          <%!-- Progress circle with gradient --%>
          <defs>
            <linearGradient id="progress-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" style="stop-color:#6366f1;stop-opacity:1" />
              <stop offset="50%" style="stop-color:#a855f7;stop-opacity:1" />
              <stop offset="100%" style="stop-color:#ec4899;stop-opacity:1" />
            </linearGradient>
          </defs>
          <circle
            cx="50"
            cy="50"
            r="40"
            stroke="url(#progress-gradient)"
            stroke-width="8"
            fill="none"
            class="transition-all duration-500"
            stroke-dasharray={circumference()}
            stroke-dashoffset={circumference() * (1 - @percentage / 100)}
            stroke-linecap="round"
          />
        </svg>
        <div class="absolute inset-0 flex items-center justify-center">
          <span class="text-2xl font-extrabold text-gray-900 dark:text-white animated-counter">
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
    <div class="date-nav-enhanced">
      <button
        phx-click="prev_day"
        class="nav-button-enhanced"
        aria-label="Previous day"
      >
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
      </button>

      <div class="flex-1 text-center">
        <h1 class="text-4xl font-extrabold text-gradient mb-2">
          <%= format_date(@selected_date, @is_today) %>
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-4 font-medium">
          <%= Calendar.strftime(@selected_date, "%A, %B %d, %Y") %>
        </p>
        <%!-- Calendar Picker --%>
        <div class="flex justify-center">
          <input
            type="date"
            id="date-picker"
            value={Date.to_iso8601(@selected_date)}
            phx-change="select_date"
            name="date"
            class="px-5 py-2.5 text-sm border-2 border-gray-300 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-4 focus:ring-indigo-200 dark:focus:ring-indigo-900/30 focus:border-indigo-500 transition-all shadow-sm hover:shadow-md spring-bounce"
            style="font-size: 16px;"
          />
        </div>
      </div>

      <button
        phx-click="next_day"
        class="nav-button-enhanced"
        aria-label="Next day"
      >
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </button>
    </div>

    <%!-- Back to Today Button --%>
    <div :if={!@is_today} class="text-center mb-6">
      <button
        phx-click="back_to_today"
        class="today-button spring-bounce"
      >
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm.707-10.293a1 1 0 00-1.414-1.414l-3 3a1 1 0 000 1.414l3 3a1 1 0 001.414-1.414L9.414 11H13a1 1 0 100-2H9.414l1.293-1.293z" clip-rule="evenodd" />
        </svg>
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

  defp get_motivational_message(completed, total) when completed == total and total > 0 do
    messages = [
      "You're on fire! 🔥",
      "Perfect day! ⭐",
      "Crushing it! 💪",
      "Amazing work! 🎯",
      "Keep it up! 🚀"
    ]
    Enum.random(messages)
  end

  defp get_motivational_message(completed, total) when completed > 0 do
    percentage = completed / total * 100
    cond do
      percentage >= 75 -> "Almost there! 💫"
      percentage >= 50 -> "Great progress! 👏"
      percentage >= 25 -> "Keep going! 💪"
      true -> "You've got this! 🌟"
    end
  end

  defp get_motivational_message(0, total) when total > 0, do: "Let's get started! 🎯"
  defp get_motivational_message(_, _), do: nil
end
