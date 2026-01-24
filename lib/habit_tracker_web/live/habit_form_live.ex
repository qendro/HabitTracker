defmodule HabitTrackerWeb.HabitFormLive do
  use HabitTrackerWeb, :live_view

  import HabitTrackerWeb.CoreComponents

  alias HabitTracker.Tracker
  alias HabitTracker.Tracker.Habit
  alias HabitTrackerWeb.HabitComponents

  @colors [
    "#3B82F6",  # Blue
    "#10B981",  # Green
    "#F59E0B",  # Amber
    "#EF4444",  # Red
    "#8B5CF6",  # Purple
    "#EC4899",  # Pink
    "#06B6D4",  # Cyan
    "#84CC16",  # Lime
    "#F97316",  # Orange
    "#6366F1",  # Indigo
    "#14B8A6",  # Teal
    "#A855F7"   # Violet
  ]

  @emojis [
    "🏃", "💪", "📚", "💧", "🧘", "🎯", "✅", "⭐", "🔥", "💯",
    "🎨", "🎵", "🎮", "📝", "💼", "🏋️", "🚴", "🏊", "🧠", "❤️",
    "🌟", "🎓", "🍎", "☕", "🌱", "🎪", "🎭", "🎬", "📱", "💻",
    "🍕", "🍔", "🥗", "🥤", "🏠", "🚗", "✈️", "🎸", "📷", "🎮",
    "⚽", "🏀", "🎾", "🏐", "🎯", "🎲", "🧩", "🎨", "🖼️", "📖",
    "✏️", "🖊️", "📐", "🔬", "🔭", "💊", "🩺", "🧬", "🌍", "🌙"
  ]

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    {mode, habit, page_title} = case params do
      %{"id" => id} ->
        habit = Tracker.get_habit!(user, String.to_integer(id))
        {:edit, habit, "Edit Habit"}
      
      _ ->
        {:new, %Habit{
          type: :binary,
          occurrence_schedule: %{"type" => "daily"},
          goal_horizon: :daily,
          icon: "⭐",
          color: "#3B82F6"
        }, "New Habit"}
    end
    
    changeset = Habit.changeset(habit, %{
      "type" => habit.type,
      "goal_horizon" => habit.goal_horizon
    })
    
    {:ok,
     socket
     |> assign(:mode, mode)
     |> assign(:habit, habit)
     |> assign(:form, to_form(changeset))
     |> assign(:page_title, page_title)
     |> assign(:colors, @colors)
     |> assign(:emojis, @emojis)
     |> assign(:selected_icon, habit.icon)
     |> assign(:selected_color, habit.color)
     |> assign(:selected_weekdays, get_selected_weekdays(habit))
     |> assign(:show_advanced, false)
     |> assign(:show_emoji_picker, false)
     |> assign(:show_color_picker, false)}
  end

  @impl true
  def handle_event("validate", %{"habit" => habit_params}, socket) do
    IO.inspect(habit_params, label: "VALIDATE PARAMS")
    
    # Convert weekdays array to occurrence_schedule
    habit_params = process_habit_params(habit_params, socket.assigns.selected_weekdays)
    
    changeset =
      socket.assigns.habit
      |> Habit.changeset(habit_params)
      |> Map.put(:action, :validate)
    
    IO.inspect(changeset.changes, label: "CHANGESET CHANGES")
    
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("select_color", %{"color" => color}, socket) do
    {:noreply, 
     socket
     |> assign(:selected_color, color)
     |> assign(:show_color_picker, false)}
  end

  @impl true
  def handle_event("select_emoji", %{"emoji" => emoji}, socket) do
    {:noreply, 
     socket
     |> assign(:selected_icon, emoji)
     |> assign(:show_emoji_picker, false)}
  end

  @impl true
  def handle_event("select_type", %{"type" => type}, socket) do
    type_atom = String.to_existing_atom(type)
    
    changeset =
      socket.assigns.habit
      |> Habit.changeset(%{"type" => type_atom})
      |> Map.put(:action, :validate)
    
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("toggle_emoji_picker", _params, socket) do
    {:noreply, 
     socket
     |> assign(:show_emoji_picker, !socket.assigns.show_emoji_picker)
     |> assign(:show_color_picker, false)}
  end

  @impl true
  def handle_event("toggle_color_picker", _params, socket) do
    {:noreply, 
     socket
     |> assign(:show_color_picker, !socket.assigns.show_color_picker)
     |> assign(:show_emoji_picker, false)}
  end

  @impl true
  def handle_event("close_pickers", _params, socket) do
    {:noreply, 
     socket
     |> assign(:show_emoji_picker, false)
     |> assign(:show_color_picker, false)}
  end

  @impl true
  def handle_event("toggle_weekday", %{"day" => day}, socket) do
    day = String.to_integer(day)
    selected_weekdays = socket.assigns.selected_weekdays
    
    new_selected_weekdays = if day in selected_weekdays do
      List.delete(selected_weekdays, day)
    else
      Enum.sort([day | selected_weekdays])
    end
    
    {:noreply, assign(socket, :selected_weekdays, new_selected_weekdays)}
  end

  @impl true
  def handle_event("select_everyday", _params, socket) do
    {:noreply, assign(socket, :selected_weekdays, [1, 2, 3, 4, 5, 6, 7])}
  end

  @impl true
  def handle_event("select_weekdays", _params, socket) do
    {:noreply, assign(socket, :selected_weekdays, [1, 2, 3, 4, 5])}
  end

  @impl true
  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :show_advanced, !socket.assigns.show_advanced)}
  end

  @impl true
  def handle_event("save", %{"habit" => habit_params}, socket) do
    # Convert weekdays array to occurrence_schedule
    habit_params = process_habit_params(habit_params, socket.assigns.selected_weekdays)
    
    # Add icon and color from assigns
    habit_params = habit_params
      |> Map.put("icon", socket.assigns.selected_icon)
      |> Map.put("color", socket.assigns.selected_color)
    
    save_habit(socket, socket.assigns.mode, habit_params)
  end

  defp save_habit(socket, :new, habit_params) do
    user = socket.assigns.current_scope.user
    
    case Tracker.create_habit(user, habit_params, socket.assigns.current_scope) do
      {:ok, _habit} ->
        {:noreply,
         socket
         |> put_flash(:info, "Habit created successfully")
         |> push_navigate(to: ~p"/app/habits")}
      
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_habit(socket, :edit, habit_params) do
    case Tracker.update_habit(socket.assigns.habit, habit_params, socket.assigns.current_scope) do
      {:ok, _habit} ->
        {:noreply,
         socket
         |> put_flash(:info, "Habit updated successfully")
         |> push_navigate(to: ~p"/app/habits")}
      
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp process_habit_params(params, selected_weekdays) do
    # Handle occurrence schedule
    params = if selected_weekdays == [] || selected_weekdays == [1, 2, 3, 4, 5, 6, 7] do
      Map.put(params, "occurrence_schedule", %{"type" => "daily"})
    else
      Map.put(params, "occurrence_schedule", %{"type" => "weekdays", "days" => selected_weekdays})
    end
    
    # Convert type to atom if it's a string
    params = if is_binary(params["type"]) do
      Map.put(params, "type", String.to_existing_atom(params["type"]))
    else
      params
    end
    
    # Convert goal_horizon to atom if it's a string
    params = if params["goal_horizon"] && is_binary(params["goal_horizon"]) do
      Map.put(params, "goal_horizon", String.to_existing_atom(params["goal_horizon"]))
    else
      params
    end
    
    params
  end

  defp get_selected_weekdays(%Habit{occurrence_schedule: %{"type" => "weekdays", "days" => days}}) do
    days
  end
  
  defp get_selected_weekdays(_), do: [1, 2, 3, 4, 5, 6, 7]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 via-blue-50/30 to-cyan-50/30 app-container">
      <%!-- Subtle animated background blobs --%>
      <div class="fixed inset-0 overflow-hidden pointer-events-none">
        <div class="absolute top-0 right-0 w-96 h-96 bg-gradient-to-br from-blue-200/20 to-cyan-200/20 rounded-full blur-3xl animate-blob"></div>
        <div class="absolute bottom-0 left-0 w-80 h-80 bg-gradient-to-tr from-indigo-200/20 to-blue-200/20 rounded-full blur-3xl animate-blob animation-delay-2000"></div>
        <div class="absolute top-1/2 left-1/2 w-72 h-72 bg-gradient-to-br from-cyan-200/20 to-teal-200/20 rounded-full blur-3xl animate-blob animation-delay-4000"></div>
      </div>

      <div class="relative max-w-3xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <.link
            navigate={~p"/app/habits"}
            class="inline-flex items-center text-blue-600 hover:text-cyan-600 transition-all mb-4 spring-bounce hover-lift"
          >
            <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            Back to Habits
          </.link>
          <h1 class="text-5xl font-extrabold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-3">
            <%= @page_title %>
          </h1>
          <p class="text-lg text-gray-600">
            <%= if @mode == :new, do: "Let's build a habit that sticks ✨", else: "Update your habit details" %>
          </p>
        </div>

        <%!-- Form Card --%>
        <div class="relative bg-white rounded-2xl shadow-sm border border-gray-100 p-10">
          <.form
            for={@form}
            id="habit-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-8"
          >
            <%!-- Essential Fields --%>
            <div class="space-y-6">
              <%!-- Form Errors --%>
              <div :if={@form.errors != []} class="p-4 bg-red-50 border-2 border-red-200 rounded-xl">
                <p class="text-sm font-medium text-red-800 mb-2">
                  Please fix the following errors:
                </p>
                <ul class="list-disc list-inside text-sm text-red-700 space-y-1">
                  <%= for {field, errors} <- @form.errors do %>
                    <%= for error <- List.wrap(errors) do %>
                      <li><%= "#{field}: #{error}" %></li>
                    <% end %>
                  <% end %>
                </ul>
              </div>

              <%!-- Name with Icon & Color Preview --%>
              <div>
                <label class="block text-sm font-bold text-gray-900 mb-4">
                  What habit do you want to build?
                </label>
                <div class="flex items-start gap-4">
                  <%!-- Icon Preview Button --%>
                  <button
                    type="button"
                    phx-click="toggle_emoji_picker"
                    class="shadow-lg hover:shadow-xl transition-all cursor-pointer"
                    title="Click to change icon"
                  >
                    <HabitComponents.habit_icon 
                      icon={@selected_icon} 
                      color={@selected_color} 
                      size="lg"
                    />
                  </button>
                  
                  <%!-- Name Input --%>
                  <div class="flex-1">
                    <input
                      type="text"
                      name="habit[name]"
                      id="habit-name"
                      value={@form[:name].value}
                      placeholder="e.g., Morning Exercise, Read 30 minutes, Drink Water"
                      class="w-full px-5 py-4 text-lg text-gray-900 border-2 border-gray-200 rounded-2xl focus:border-indigo-500 focus:ring-4 focus:ring-indigo-200 transition-all spring-bounce"
                      required
                    />
                    <p class="text-xs text-gray-500 mt-2 font-medium">
                      💡 Click the icon or color to customize
                    </p>
                  </div>
                </div>
                
                <%!-- Color Swatch Button --%>
                <button
                  type="button"
                  phx-click="toggle_color_picker"
                  class="mt-3 w-20 h-10 rounded-xl shadow-lg hover:shadow-xl transition-all spring-bounce hover-lift border-2 border-white"
                  style={"background-color: #{@selected_color}"}
                  title="Click to change color"
                >
                </button>
              </div>

              <%!-- Habit Type (Compact & Clean) --%>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  How do you track it?
                </label>
                <div class="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    phx-click="select_type"
                    phx-value-type="binary"
                    class={[
                      "relative flex flex-col items-center p-3 border-2 rounded-lg cursor-pointer transition-all",
                      if(@form[:type].value == :binary,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300 bg-white"
                      )
                    ]}
                  >
                    <div class="text-2xl mb-1 text-gray-700">✓</div>
                    <div class="font-medium text-gray-900 text-xs">Yes/No</div>
                  </button>

                  <button
                    type="button"
                    phx-click="select_type"
                    phx-value-type="numeric"
                    class={[
                      "relative flex flex-col items-center p-3 border-2 rounded-lg cursor-pointer transition-all",
                      if(@form[:type].value == :numeric,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300 bg-white"
                      )
                    ]}
                  >
                    <div class="text-2xl mb-1 text-gray-700">#</div>
                    <div class="font-medium text-gray-900 text-xs">Count</div>
                  </button>

                  <button
                    type="button"
                    phx-click="select_type"
                    phx-value-type="duration"
                    class={[
                      "relative flex flex-col items-center p-3 border-2 rounded-lg cursor-pointer transition-all",
                      if(@form[:type].value == :duration,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300 bg-white"
                      )
                    ]}
                  >
                    <div class="text-2xl mb-1 text-gray-700">⏱</div>
                    <div class="font-medium text-gray-900 text-xs">Time</div>
                  </button>
                </div>
                <%!-- Hidden input to submit the type --%>
                <input type="hidden" name="habit[type]" value={@form[:type].value} />
              </div>

              <%!-- Target Value (Inline for numeric/duration) --%>
              <div :if={@form[:type].value in [:numeric, :duration]} class="flex gap-3">
                <div class="flex-1">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    <%= if @form[:type].value == :duration, do: "Target (minutes)", else: "Target" %>
                  </label>
                  <input
                    type="number"
                    name="habit[target_value]"
                    value={@form[:target_value].value}
                    step={if @form[:type].value == :numeric, do: "0.01", else: "1"}
                    min="0"
                    placeholder={if @form[:type].value == :duration, do: "30", else: "8"}
                    class="w-full px-4 py-2.5 text-gray-900 border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-2 focus:ring-blue-200"
                    required
                  />
                </div>
                <div :if={@form[:type].value == :numeric} class="flex-1">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Unit (optional)
                  </label>
                  <input
                    type="text"
                    name="habit[unit_label]"
                    value={@form[:unit_label].value}
                    placeholder="glasses, pages, km"
                    class="w-full px-4 py-2.5 text-gray-900 border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-2 focus:ring-blue-200"
                  />
                </div>
              </div>

              <%!-- Schedule (Clean with Quick Select) --%>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Which days?
                </label>
                
                <%!-- Quick Select Buttons --%>
                <div class="flex gap-2 mb-3">
                  <button
                    type="button"
                    phx-click="select_everyday"
                    class={[
                      "flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-all",
                      if(@selected_weekdays == [1, 2, 3, 4, 5, 6, 7],
                        do: "bg-blue-500 text-white shadow-md",
                        else: "bg-gray-100 text-gray-600 hover:bg-gray-200"
                      )
                    ]}
                  >
                    Everyday
                  </button>
                  <button
                    type="button"
                    phx-click="select_weekdays"
                    class={[
                      "flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-all",
                      if(@selected_weekdays == [1, 2, 3, 4, 5],
                        do: "bg-blue-500 text-white shadow-md",
                        else: "bg-gray-100 text-gray-600 hover:bg-gray-200"
                      )
                    ]}
                  >
                    Weekdays
                  </button>
                </div>

                <%!-- Individual Day Selection --%>
                <div class="grid grid-cols-7 gap-1.5">
                  <%= for {day_name, day_num} <- [{"M", 1}, {"T", 2}, {"W", 3}, {"T", 4}, {"F", 5}, {"S", 6}, {"S", 7}] do %>
                    <button
                      type="button"
                      phx-click="toggle_weekday"
                      phx-value-day={day_num}
                      class={[
                        "py-2.5 rounded-lg text-sm font-medium transition-all",
                        if(day_num in @selected_weekdays,
                          do: "bg-blue-500 text-white shadow-sm",
                          else: "bg-gray-100 text-gray-500 hover:bg-gray-200"
                        )
                      ]}
                    >
                      <%= day_name %>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Advanced Options (Collapsible) --%>
            <div class="border-t border-gray-200 pt-6">
              <button
                type="button"
                phx-click="toggle_advanced"
                class="flex items-center justify-between w-full text-left"
              >
                <span class="text-sm font-medium text-gray-700">
                  Advanced Options
                </span>
                <svg
                  class={[
                    "w-5 h-5 text-gray-400 transition-transform",
                    if(@show_advanced, do: "rotate-180", else: "")
                  ]}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              <div :if={@show_advanced} class="mt-4 space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Description
                  </label>
                  <textarea
                    name="habit[description]"
                    rows="3"
                    placeholder="Add any notes or details about this habit..."
                    class="w-full px-4 py-2.5 text-gray-900 border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-2 focus:ring-blue-200 resize-none"
                  >{@form[:description].value}</textarea>
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Goal Horizon
                    </label>
                    <select
                      name="habit[goal_horizon]"
                      class="w-full px-4 py-2.5 text-gray-900 border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-2 focus:ring-blue-200"
                    >
                      <option value="daily" selected={@form[:goal_horizon].value == :daily}>
                        Daily
                      </option>
                      <option value="weekly" selected={@form[:goal_horizon].value == :weekly}>
                        Weekly
                      </option>
                      <option value="monthly" selected={@form[:goal_horizon].value == :monthly}>
                        Monthly
                      </option>
                      <option value="yearly" selected={@form[:goal_horizon].value == :yearly}>
                        Yearly
                      </option>
                    </select>
                  </div>

                  <div :if={@form[:goal_horizon].value != :daily}>
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Times per <%= @form[:goal_horizon].value %>
                    </label>
                    <input
                      type="number"
                      name="habit[frequency_goal]"
                      value={@form[:frequency_goal].value}
                      min="1"
                      class="w-full px-4 py-2.5 text-gray-900 border-2 border-gray-200 rounded-xl focus:border-blue-500 focus:ring-2 focus:ring-blue-200"
                      required
                    />
                  </div>
                </div>
              </div>
            </div>

            <%!-- Action Buttons --%>
            <div class="flex items-center justify-between pt-8 border-t border-gray-200">
              <.link
                navigate={~p"/app/habits"}
                class="px-8 py-3 text-gray-600 hover:bg-gray-100 rounded-xl transition-all font-semibold spring-bounce"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="px-10 py-4 bg-gradient-to-r from-blue-600 to-cyan-600 hover:opacity-90 text-white rounded-xl font-bold shadow-xl hover:shadow-2xl transition-all spring-bounce hover-lift text-lg"
              >
                <%= if @mode == :new, do: "✨ Create Habit", else: "💾 Save Changes" %>
              </button>
            </div>
          </.form>
        </div>

        <%!-- Emoji Picker Modal --%>
        <div
          :if={@show_emoji_picker}
          class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
          phx-click="close_pickers"
        >
          <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full max-h-[80vh] overflow-hidden">
            <%!-- Modal Header --%>
            <div class="flex items-center justify-between p-4 border-b border-gray-200">
              <h3 class="text-lg font-semibold text-gray-900">
                Choose an Icon
              </h3>
              <button
                type="button"
                phx-click="close_pickers"
                class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <%!-- Emoji Grid --%>
            <div class="p-4 overflow-y-auto max-h-[60vh]">
              <div class="grid grid-cols-6 gap-2">
                <%= for emoji <- @emojis do %>
                  <button
                    type="button"
                    phx-click="select_emoji"
                    phx-value-emoji={emoji}
                    class={[
                      "w-12 h-12 rounded-lg text-2xl flex items-center justify-center transition-all hover:scale-110 active:scale-95",
                      if(@selected_icon == emoji,
                        do: "bg-blue-100 ring-2 ring-blue-500 scale-105",
                        else: "hover:bg-gray-100"
                      )
                    ]}
                    title={emoji}
                  >
                    <%= emoji %>
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <%!-- Color Picker Modal --%>
        <div
          :if={@show_color_picker}
          class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
          phx-click="close_pickers"
        >
          <div class="bg-white rounded-2xl shadow-2xl max-w-sm w-full">
            <%!-- Modal Header --%>
            <div class="flex items-center justify-between p-4 border-b border-gray-200">
              <h3 class="text-lg font-semibold text-gray-900">
                Choose a Color
              </h3>
              <button
                type="button"
                phx-click="close_pickers"
                class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <%!-- Color Grid --%>
            <div class="p-6">
              <div class="grid grid-cols-4 gap-3">
                <%= for color <- @colors do %>
                  <button
                    type="button"
                    phx-click="select_color"
                    phx-value-color={color}
                    class={[
                      "w-16 h-16 rounded-xl transition-all hover:scale-110 active:scale-95 shadow-md hover:shadow-lg",
                      if(@selected_color == color,
                        do: "ring-4 ring-blue-500 ring-offset-2 scale-105",
                        else: ""
                      )
                    ]}
                    style={"background-color: #{color}"}
                    title={color}
                  >
                    <div :if={@selected_color == color} class="w-full h-full flex items-center justify-center">
                      <svg class="w-8 h-8 text-white drop-shadow-lg" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                      </svg>
                    </div>
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
