defmodule HabitTrackerWeb.HabitFormLive do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Tracker
  alias HabitTracker.Tracker.Habit

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
    "🌟", "🎓", "🍎", "☕", "🌱", "🎪", "🎭", "🎬", "📱", "💻"
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
          active: true
        }, "New Habit"}
    end
    
    changeset = Habit.changeset(habit, %{})
    
    {:ok,
     socket
     |> assign(:mode, mode)
     |> assign(:habit, habit)
     |> assign(:form, to_form(changeset))
     |> assign(:page_title, page_title)
     |> assign(:colors, @colors)
     |> assign(:emojis, @emojis)
     |> assign(:selected_weekdays, get_selected_weekdays(habit))}
  end

  @impl true
  def handle_event("validate", %{"habit" => habit_params}, socket) do
    # Convert weekdays array to occurrence_schedule
    habit_params = process_habit_params(habit_params, socket.assigns.selected_weekdays)
    
    changeset =
      socket.assigns.habit
      |> Habit.changeset(habit_params)
      |> Map.put(:action, :validate)
    
    {:noreply, assign(socket, form: to_form(changeset))}
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
  def handle_event("save", %{"habit" => habit_params}, socket) do
    # Convert weekdays array to occurrence_schedule
    habit_params = process_habit_params(habit_params, socket.assigns.selected_weekdays)
    
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
    <div class="min-h-screen bg-gray-50 dark:bg-gray-900">
      <div class="max-w-2xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="mb-6">
          <.link
            navigate={~p"/app/habits"}
            class="text-blue-600 dark:text-blue-400 hover:underline mb-2 inline-block"
          >
            ← Back to Habits
          </.link>
          <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
            <%= @page_title %>
          </h1>
        </div>

        <%!-- Form --%>
        <.form
          for={@form}
          id="habit-form"
          phx-change="validate"
          phx-submit="save"
          class="space-y-6"
        >
          <%!-- Name --%>
          <div>
            <.input
              field={@form[:name]}
              type="text"
              label="Habit Name"
              placeholder="e.g., Morning Exercise"
              required
            />
          </div>

          <%!-- Description --%>
          <div>
            <.input
              field={@form[:description]}
              type="textarea"
              label="Description (optional)"
              placeholder="Add details about this habit..."
            />
          </div>

          <%!-- Icon Picker --%>
          <div>
            <label class="block text-sm font-semibold text-gray-900 dark:text-white mb-2">
              Icon
            </label>
            <div class="grid grid-cols-10 gap-2">
              <%= for emoji <- @emojis do %>
                <button
                  type="button"
                  phx-click={JS.exec("phx-click", to: "#icon-input", attr: ["data-emoji", emoji])}
                  class={[
                    "text-2xl p-2 rounded-lg border-2 transition-all hover:scale-110",
                    if(@form[:icon].value == emoji,
                      do: "border-blue-500 bg-blue-50 dark:bg-blue-900/20",
                      else: "border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600"
                    )
                  ]}
                >
                  <%= emoji %>
                </button>
              <% end %>
            </div>
            <input
              type="hidden"
              id="icon-input"
              name="habit[icon]"
              value={@form[:icon].value}
              phx-click={JS.dispatch("change", to: "#habit-form")}
              data-emoji=""
            />
            <script>
              document.getElementById('icon-input').addEventListener('phx-click', function(e) {
                const emoji = e.target.getAttribute('data-emoji');
                if (emoji) {
                  this.value = emoji;
                  this.dispatchEvent(new Event('change', { bubbles: true }));
                }
              });
            </script>
          </div>

          <%!-- Color Picker --%>
          <div>
            <label class="block text-sm font-semibold text-gray-900 dark:text-white mb-2">
              Color
            </label>
            <div class="grid grid-cols-12 gap-2">
              <%= for color <- @colors do %>
                <button
                  type="button"
                  phx-click={JS.exec("phx-click", to: "#color-input", attr: ["data-color", color])}
                  class={[
                    "w-10 h-10 rounded-lg border-2 transition-all hover:scale-110",
                    if(@form[:color].value == color,
                      do: "border-gray-900 dark:border-white ring-2 ring-offset-2 ring-gray-900 dark:ring-white",
                      else: "border-gray-200 dark:border-gray-700"
                    )
                  ]}
                  style={"background-color: #{color}"}
                >
                </button>
              <% end %>
            </div>
            <input
              type="hidden"
              id="color-input"
              name="habit[color]"
              value={@form[:color].value}
              phx-click={JS.dispatch("change", to: "#habit-form")}
              data-color=""
            />
            <script>
              document.getElementById('color-input').addEventListener('phx-click', function(e) {
                const color = e.target.getAttribute('data-color');
                if (color) {
                  this.value = color;
                  this.dispatchEvent(new Event('change', { bubbles: true }));
                }
              });
            </script>
          </div>

          <%!-- Habit Type --%>
          <div>
            <label class="block text-sm font-semibold text-gray-900 dark:text-white mb-2">
              Habit Type
            </label>
            <div class="space-y-2">
              <label class="flex items-center p-3 border-2 rounded-lg cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                <input
                  type="radio"
                  name="habit[type]"
                  value="binary"
                  checked={@form[:type].value == :binary}
                  class="mr-3"
                />
                <div>
                  <div class="font-medium text-gray-900 dark:text-white">Yes/No</div>
                  <div class="text-sm text-gray-600 dark:text-gray-400">
                    Simple completion tracking (e.g., Did you exercise?)
                  </div>
                </div>
              </label>

              <label class="flex items-center p-3 border-2 rounded-lg cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                <input
                  type="radio"
                  name="habit[type]"
                  value="numeric"
                  checked={@form[:type].value == :numeric}
                  class="mr-3"
                />
                <div>
                  <div class="font-medium text-gray-900 dark:text-white">Numeric</div>
                  <div class="text-sm text-gray-600 dark:text-gray-400">
                    Track a measurable value (e.g., 8 glasses of water)
                  </div>
                </div>
              </label>

              <label class="flex items-center p-3 border-2 rounded-lg cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                <input
                  type="radio"
                  name="habit[type]"
                  value="duration"
                  checked={@form[:type].value == :duration}
                  class="mr-3"
                />
                <div>
                  <div class="font-medium text-gray-900 dark:text-white">Duration</div>
                  <div class="text-sm text-gray-600 dark:text-gray-400">
                    Track time spent (e.g., 30 minutes of meditation)
                  </div>
                </div>
              </label>
            </div>
          </div>

          <%!-- Target Value (for numeric/duration) --%>
          <div :if={@form[:type].value in [:numeric, :duration]}>
            <.input
              field={@form[:target_value]}
              type="number"
              label={if @form[:type].value == :duration, do: "Target (minutes)", else: "Target Value"}
              step={if @form[:type].value == :numeric, do: "0.01", else: "1"}
              min="0"
              required
            />
          </div>

          <%!-- Unit Label (for numeric) --%>
          <div :if={@form[:type].value == :numeric}>
            <.input
              field={@form[:unit_label]}
              type="text"
              label="Unit Label (optional)"
              placeholder="e.g., glasses, pages, km"
            />
          </div>

          <%!-- Goal Horizon --%>
          <div>
            <.input
              field={@form[:goal_horizon]}
              type="select"
              label="Goal Horizon"
              options={[
                {"Daily", "daily"},
                {"Weekly", "weekly"},
                {"Monthly", "monthly"},
                {"Yearly", "yearly"}
              ]}
            />
          </div>

          <%!-- Frequency Goal (for non-daily) --%>
          <div :if={@form[:goal_horizon].value != :daily}>
            <.input
              field={@form[:frequency_goal]}
              type="number"
              label={"Times per #{@form[:goal_horizon].value}"}
              min="1"
              required
            />
          </div>

          <%!-- Occurrence Schedule --%>
          <div>
            <label class="block text-sm font-semibold text-gray-900 dark:text-white mb-2">
              Schedule
            </label>
            <div class="flex flex-wrap gap-2">
              <%= for {day_name, day_num} <- [{"Mon", 1}, {"Tue", 2}, {"Wed", 3}, {"Thu", 4}, {"Fri", 5}, {"Sat", 6}, {"Sun", 7}] do %>
                <button
                  type="button"
                  phx-click="toggle_weekday"
                  phx-value-day={day_num}
                  class={[
                    "px-4 py-2 rounded-lg font-medium transition-colors",
                    if(day_num in @selected_weekdays,
                      do: "bg-blue-500 text-white",
                      else: "bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600"
                    )
                  ]}
                >
                  <%= day_name %>
                </button>
              <% end %>
            </div>
            <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
              <%= if @selected_weekdays == [1, 2, 3, 4, 5, 6, 7] do %>
                Daily schedule
              <% else %>
                <%= length(@selected_weekdays) %> days per week
              <% end %>
            </p>
          </div>

          <%!-- Submit Buttons --%>
          <div class="flex items-center justify-end space-x-3 pt-4">
            <.link
              navigate={~p"/app/habits"}
              class="px-4 py-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg transition-colors"
            >
              Cancel
            </.link>
            <button
              type="submit"
              class="px-6 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg font-medium transition-colors"
            >
              <%= if @mode == :new, do: "Create Habit", else: "Update Habit" %>
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
