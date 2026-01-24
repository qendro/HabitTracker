defmodule HabitTrackerWeb.HabitComponents do
  @moduledoc """
  Reusable habit-related UI components.
  """
  use Phoenix.Component
  import HabitTrackerWeb.CoreComponents

  @doc """
  Renders a unified habit icon with consistent styling.

  ## Examples

      <.habit_icon icon="🏃" color="#3B82F6" size="md" />
  """
  attr :icon, :string, required: true
  attr :color, :string, required: true
  attr :size, :string, default: "md" # sm, md, lg
  attr :class, :string, default: ""

  def habit_icon(assigns) do
    {size_classes, size_px} = case assigns.size do
      "sm" -> {"text-2xl", "48px"}
      "md" -> {"text-3xl", "56px"}
      "lg" -> {"text-4xl", "80px"}
      _ -> {"text-3xl", "56px"}
    end
    
    assigns = assign(assigns, :size_classes, size_classes)
    assigns = assign(assigns, :size_px, size_px)
    
    ~H"""
    <div
      class={"relative flex items-center justify-center transition-all duration-300 #{@size_classes} #{@class}"}
      style={"width: #{@size_px}; height: #{@size_px}; background: linear-gradient(135deg, #{@color}10, #{@color}05); color: #{@color}; border-radius: 12px; border: 2px solid #{@color}25;"}
    >
      <%= @icon %>
    </div>
    """
  end

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
    <div 
      id={"habit-card-#{@habit.id}"} 
      class="group relative bg-white rounded-2xl shadow-sm hover:shadow-lg p-6 mb-4 border border-gray-100 transition-all duration-300 hover:-translate-y-1"
    >
      <%!-- Subtle accent line on left --%>
      <div 
        class="absolute left-0 top-6 bottom-6 w-1 rounded-r-full transition-all duration-300 group-hover:w-1.5"
        style={"background: linear-gradient(to bottom, #{@habit.color}, #{@habit.color}80);"}
      >
      </div>

      <div class="flex items-start justify-between gap-4 pl-3">
        <div class="flex items-start gap-4 flex-1 min-w-0">
          <%!-- Icon with subtle glow effect --%>
          <.habit_icon 
            icon={@habit.icon} 
            color={@habit.color} 
            size="md"
            class="group-hover:scale-105"
          />

          <%!-- Habit Info --%>
          <div class="flex-1 min-w-0">
            <h3 class="text-lg font-bold text-gray-900 mb-1 leading-tight">
              <%= @habit.name %>
            </h3>
            <p :if={@habit.description} class="text-sm text-gray-600 mb-3 leading-relaxed">
              <%= @habit.description %>
            </p>

            <%!-- Progress and Streak on same line --%>
            <div class="mt-3 flex items-center gap-3 flex-wrap">
              <%= case @progress.type do %>
                <% :binary -> %>
                  <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-semibold transition-all duration-200" style={get_status_style(@progress.status, @habit.color)}>
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
                          <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    <% end %>
                    <%= status_label(@progress.status) %>
                  </div>
                <% :numeric -> %>
                  <div class="flex-1 space-y-2.5">
                    <div class="flex items-center justify-between text-sm">
                      <span class="font-semibold text-gray-700">
                        <%= @progress.current %> / <%= @progress.target %>
                        <%= if @progress.unit, do: @progress.unit %>
                      </span>
                      <span class="text-lg font-bold" style={"color: #{if @progress.percentage >= 100, do: "#10b981", else: @habit.color};"}>
                        <%= @progress.percentage %>%
                      </span>
                    </div>
                    <div class="relative h-2.5 bg-gray-100 rounded-full overflow-hidden">
                      <div
                        class="absolute inset-y-0 left-0 rounded-full transition-all duration-500 ease-out"
                        style={"width: #{min(@progress.percentage, 100)}%; background: linear-gradient(90deg, #{@habit.color}, #{@habit.color}cc);"}
                      >
                        <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white to-transparent opacity-30 animate-shimmer"></div>
                      </div>
                    </div>
                  </div>
                <% :duration -> %>
                  <div class="flex-1 space-y-2.5">
                    <div class="flex items-center justify-between text-sm">
                      <span class="font-semibold text-gray-700">
                        <%= @progress.current %> / <%= @progress.target %> <%= @progress.unit %>
                      </span>
                      <span class="text-lg font-bold" style={"color: #{if @progress.percentage >= 100, do: "#10b981", else: @habit.color};"}>
                        <%= @progress.percentage %>%
                      </span>
                    </div>
                    <div class="relative h-2.5 bg-gray-100 rounded-full overflow-hidden">
                      <div
                        class="absolute inset-y-0 left-0 rounded-full transition-all duration-500 ease-out"
                        style={"width: #{min(@progress.percentage, 100)}%; background: linear-gradient(90deg, #{@habit.color}, #{@habit.color}cc);"}
                      >
                        <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white to-transparent opacity-30 animate-shimmer"></div>
                      </div>
                    </div>
                  </div>
              <% end %>

              <%!-- Streak Badge on same line --%>
              <div :if={@streak > 0} class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-bold bg-gradient-to-r from-orange-50 to-red-50 text-orange-700 border border-orange-200">
                <span class="text-base">🔥</span>
                <%= @streak %> day<%= if @streak != 1, do: "s" %>
              </div>
              <span :if={@is_future && @streak > 0} class="text-xs text-gray-500 italic">
                (as of today)
              </span>
            </div>
          </div>
        </div>

        <%!-- Action Buttons --%>
        <div class="flex flex-col items-center gap-3 flex-shrink-0">
          <%!-- Binary habit toggle button --%>
          <button
            :if={@habit.type == :binary && !@readonly}
            phx-click="toggle_habit"
            phx-value-habit-id={@habit.id}
            class="relative flex items-center justify-center transition-all duration-300 shadow-sm hover:shadow-md hover:scale-105 active:scale-95"
            style={
              if @is_complete do
                "width: 56px; height: 56px; background: linear-gradient(135deg, #4ade80 0%, #16a34a 100%); color: white; box-shadow: 0 4px 12px rgba(34, 197, 94, 0.4); border-radius: 50%;"
              else
                "width: 56px; height: 56px; background: #f3f4f6; color: white; border-radius: 50%;"
              end
            }
            aria-label={if @is_complete, do: "Mark as incomplete", else: "Mark as complete"}
          >
            <svg class="w-7 h-7" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
          </button>

          <%!-- Read-only indicator for binary habits --%>
          <div
            :if={@habit.type == :binary && @readonly}
            class="flex items-center justify-center shadow-sm"
            style={
              if @is_complete do
                "width: 56px; height: 56px; background: linear-gradient(135deg, #4ade80 0%, #16a34a 100%); color: white; border-radius: 50%;"
              else
                "width: 56px; height: 56px; background: #f3f4f6; color: white; border-radius: 50%;"
              end
            }
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
              class="w-24 px-3 py-2.5 text-sm font-semibold border-2 border-gray-200 rounded-xl bg-white text-gray-900 focus:ring-2 focus:border-transparent transition-all"
              style={"font-size: 16px; --tw-ring-color: #{@habit.color}40;"}
            />
            <input type="hidden" name="habit-id" value={@habit.id} />
            <button
              type="submit"
              class="w-14 h-14 rounded-2xl flex items-center justify-center text-white transition-all duration-300 shadow-sm hover:shadow-md hover:scale-105 active:scale-95"
              style={"background: linear-gradient(135deg, #{@habit.color}, #{@habit.color}dd);"}
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
              class="w-24 px-3 py-2.5 text-sm font-semibold border-2 border-gray-200 rounded-xl bg-gray-50 text-gray-500"
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
    assigns = assign(assigns, :ring_color, get_ring_color(assigns.completed, assigns.total))

    ~H"""
    <div class="relative bg-gradient-to-br from-blue-50 via-white to-cyan-50 rounded-2xl shadow-sm border border-blue-100 p-6 overflow-hidden">
      <%!-- Subtle animated background --%>
      <div class="absolute inset-0 opacity-30">
        <div class="absolute top-0 right-0 w-48 h-48 bg-gradient-to-br from-blue-200 to-cyan-200 rounded-full blur-3xl transform translate-x-1/2 -translate-y-1/2"></div>
        <div class="absolute bottom-0 left-0 w-32 h-32 bg-gradient-to-tr from-indigo-200 to-blue-200 rounded-full blur-3xl transform -translate-x-1/2 translate-y-1/2"></div>
      </div>

      <div class="relative flex items-center justify-between">
        <div class="flex-1">
          <div class="flex items-baseline gap-2 mb-1">
            <span class="text-4xl font-extrabold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
              <%= @completed %>
            </span>
            <span class="text-2xl font-bold text-gray-400">/</span>
            <span class="text-2xl font-bold text-gray-600">
              <%= @total %>
            </span>
          </div>
          <p class="text-xs font-semibold text-gray-600 uppercase tracking-wide mb-2">
            Habits Complete
          </p>
          <p :if={@motivational_message} class="inline-flex items-center gap-2 text-sm font-bold text-indigo-600 bg-indigo-50 px-3 py-1.5 rounded-lg">
            <%= get_emoji(@completed, @total) %>
            <%= @motivational_message %>
          </p>
        </div>

        <%!-- Progress Ring --%>
        <div class="relative w-28 h-28 flex-shrink-0">
          <svg class="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
            <%!-- Background circle --%>
            <circle
              cx="50"
              cy="50"
              r="37"
              stroke="currentColor"
              stroke-width="12"
              fill="none"
              class="text-gray-200"
            />
            <%!-- Progress circle --%>
            <circle
              cx="50"
              cy="50"
              r="37"
              stroke={"url(#progress-gradient-#{@ring_color})"}
              stroke-width="12"
              fill="none"
              class="transition-all duration-700 ease-out"
              stroke-dasharray={circumference()}
              stroke-dashoffset={circumference() * (1 - @percentage / 100)}
              stroke-linecap="round"
            />
            <defs>
              <%!-- Blue gradient for progress --%>
              <linearGradient id="progress-gradient-progress" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" style="stop-color:#3b82f6;stop-opacity:1" />
                <stop offset="100%" style="stop-color:#06b6d4;stop-opacity:1" />
              </linearGradient>
              <%!-- Gray for not started --%>
              <linearGradient id="progress-gradient-none" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" style="stop-color:#9ca3af;stop-opacity:1" />
                <stop offset="100%" style="stop-color:#6b7280;stop-opacity:1" />
              </linearGradient>
            </defs>
          </svg>
          <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div class="text-center">
              <div class="flex items-baseline justify-center">
                <span class={"text-lg font-extrabold #{get_percentage_color(@ring_color)}"} style="line-height: 1;">
                  <%= round(@percentage) %>
                </span>
                <span class="text-xs font-bold text-gray-400" style="line-height: 1;">%</span>
              </div>
            </div>
          </div>
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
    <div class="relative bg-white rounded-2xl shadow-sm border border-gray-100 p-5 mb-6">
      <div class="flex items-center justify-between gap-4">
        <button
          phx-click="prev_day"
          class="w-12 h-12 rounded-xl flex items-center justify-center text-gray-600 hover:text-blue-600 hover:bg-blue-50 transition-all duration-200 hover:scale-105 active:scale-95"
          aria-label="Previous day"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M15 19l-7-7 7-7" />
          </svg>
        </button>

        <div class="flex-1 text-center">
          <h1 class="text-3xl font-extrabold mb-1">
            <span class="bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
              <%= format_date(@selected_date, @is_today) %>
            </span>
          </h1>
          <p class="text-sm text-gray-600 font-medium mb-3">
            <%= Calendar.strftime(@selected_date, "%A, %B %d, %Y") %>
          </p>
          <div class="flex justify-center">
            <input
              type="date"
              id="date-picker"
              value={Date.to_iso8601(@selected_date)}
              phx-change="select_date"
              name="date"
              class="px-4 py-2 text-sm font-semibold border-2 border-gray-200 rounded-xl bg-gray-50 text-gray-900 hover:bg-white hover:border-blue-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
              style="font-size: 16px;"
            />
          </div>
        </div>

        <button
          phx-click="next_day"
          class="w-12 h-12 rounded-xl flex items-center justify-center text-gray-600 hover:text-blue-600 hover:bg-blue-50 transition-all duration-200 hover:scale-105 active:scale-95"
          aria-label="Next day"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>
    </div>

    <%!-- Back to Today Button --%>
    <div :if={!@is_today} class="text-center mb-6">
      <button
        phx-click="back_to_today"
        class="inline-flex items-center gap-2 px-6 py-3 text-sm font-bold text-white bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700 rounded-xl transition-all duration-200 shadow-sm hover:shadow-md hover:-translate-y-0.5 active:translate-y-0"
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

  defp status_color(:complete), do: "bg-green-100 text-green-800"
  defp status_color(:planned), do: "bg-blue-100 text-blue-800"
  defp status_color(:not_complete), do: "bg-gray-100 text-gray-800"

  defp status_label(:complete), do: "Complete"
  defp status_label(:planned), do: "Planned"
  defp status_label(:not_complete), do: "Not Complete"

  defp get_status_style(:complete, color) do
    "background: linear-gradient(135deg, #{color}15, #{color}08); color: #{color}; border: 1.5px solid #{color}30;"
  end
  
  defp get_status_style(:planned, _color) do
    "background: linear-gradient(135deg, #dbeafe, #eff6ff); color: #1e40af; border: 1.5px solid #93c5fd;"
  end
  
  defp get_status_style(:not_complete, _color) do
    "background: #f3f4f6; color: #6b7280; border: 1.5px solid #e5e7eb;"
  end

  defp get_emoji(completed, total) when completed == total and total > 0, do: "🎉"
  defp get_emoji(completed, total) when completed > 0 do
    percentage = completed / total * 100
    cond do
      percentage >= 75 -> "💫"
      percentage >= 50 -> "👏"
      percentage >= 25 -> "💪"
      true -> "🌟"
    end
  end
  defp get_emoji(_, _), do: "🎯"

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

  defp circumference, do: 2 * :math.pi() * 37

  defp get_motivational_message(completed, total) when completed == total and total > 0 do
    messages = [
      "Perfect day!",
      "You're crushing it!",
      "Amazing work!",
      "All done!",
      "Flawless!"
    ]
    Enum.random(messages)
  end

  defp get_motivational_message(completed, total) when completed > 0 do
    percentage = completed / total * 100
    cond do
      percentage >= 75 -> "Almost there!"
      percentage >= 50 -> "Great progress!"
      percentage >= 25 -> "Keep going!"
      true -> "You've got this!"
    end
  end

  defp get_motivational_message(0, total) when total > 0, do: "Let's get started!"
  defp get_motivational_message(_, _), do: nil

  defp get_ring_color(0, total) when total > 0, do: "none"
  defp get_ring_color(completed, _total) when completed > 0, do: "progress"
  defp get_ring_color(_, _), do: "none"

  defp get_percentage_color("progress"), do: "bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent"
  defp get_percentage_color("none"), do: "text-gray-500"
end
