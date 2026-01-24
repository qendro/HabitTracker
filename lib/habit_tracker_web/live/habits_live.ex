defmodule HabitTrackerWeb.HabitsLive do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Tracker
  alias HabitTrackerWeb.HabitComponents

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    # Load all habits
    habits = Tracker.list_habits(user)
    
    {:ok,
     socket
     |> assign(:habits, habits)}
  end

  @impl true
  def handle_event("delete_habit", %{"habit-id" => habit_id}, socket) do
    habit_id = String.to_integer(habit_id)
    
    # Find the habit
    habit = Enum.find(socket.assigns.habits, &(&1.id == habit_id))
    
    if habit do
      case Tracker.delete_habit(habit, socket.assigns.current_scope) do
        {:ok, _deleted_habit} ->
          # Reload habits
          user = socket.assigns.current_scope.user
          habits = Tracker.list_habits(user)
          
          {:noreply,
           socket
           |> assign(:habits, habits)
           |> put_flash(:info, "Habit deleted")}
        
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete habit")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reorder", %{"habit_ids" => habit_ids}, socket) do
    user = socket.assigns.current_scope.user
    
    # Convert IDs to integers (handle both string and integer inputs)
    habit_ids = Enum.map(habit_ids, fn
      id when is_binary(id) -> String.to_integer(id)
      id when is_integer(id) -> id
    end)
    
    case Tracker.reorder_habits(user, habit_ids) do
      :ok ->
        # Reload habits to reflect new positions
        habits = Tracker.list_habits(user)
        
        {:noreply,
         socket
         |> assign(:habits, habits)
         |> put_flash(:info, "Habits reordered")}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to reorder habits")}
    end
  end

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

      <div class="relative max-w-4xl mx-auto px-4 py-8">
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-5xl font-extrabold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent mb-2">
              My Habits
            </h1>
            <p class="text-gray-600">
              Manage and organize your habits
            </p>
          </div>
          <.link
            navigate={~p"/app/habits/new"}
            class="inline-flex items-center gap-2 px-6 py-3 text-sm font-bold text-white bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700 rounded-xl transition-all duration-200 shadow-lg hover:shadow-xl hover:-translate-y-0.5"
          >
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
            </svg>
            New Habit
          </.link>
        </div>

        <%!-- Habits List --%>
        <div id="habits-list" phx-hook=".HabitSortable" class="space-y-4">
          <%= for habit <- @habits do %>
            <.habit_card habit={habit} />
          <% end %>

          <div :if={@habits == []} class="relative bg-white rounded-2xl shadow-sm border-2 border-dashed border-gray-200 p-16 text-center">
            <div class="flex flex-col items-center">
              <div class="w-24 h-24 bg-gradient-to-br from-blue-100 to-cyan-100 rounded-full flex items-center justify-center mb-6">
                <svg class="w-12 h-12 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-gray-900 mb-2">
                No habits yet. Create your first habit to get started!
              </h2>
              <p class="text-gray-600 mb-8 max-w-md">
                Start building better routines by creating your first habit.
              </p>
              <.link
                navigate={~p"/app/habits/new"}
                class="inline-flex items-center gap-2 px-6 py-3 text-sm font-bold text-white bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700 rounded-xl transition-all duration-200 shadow-sm hover:shadow-md hover:-translate-y-0.5"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
                </svg>
                Create Your First Habit
              </.link>
            </div>
          </div>
        </div>

        <%!-- Sortable Hook Script --%>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".HabitSortable">
          export default {
            mounted() {
              this.initSortable();
            },
            
            updated() {
              // Reinitialize sortable after DOM updates
              if (this.sortable) {
                this.sortable.destroy();
              }
              this.initSortable();
            },
            
            initSortable() {
              const sortable = window.Sortable.create(this.el, {
                animation: 150,
                handle: '.drag-handle',
                ghostClass: 'opacity-50',
                onEnd: (evt) => {
                  // Get all habit IDs in the new order
                  const habitIds = Array.from(this.el.querySelectorAll('[data-habit-id]'))
                    .map(el => el.dataset.habitId);
                  
                  // Push the reorder event to the server
                  this.pushEvent("reorder", { habit_ids: habitIds });
                }
              });
              
              // Store sortable instance for cleanup
              this.sortable = sortable;
            },
            
            destroyed() {
              if (this.sortable) {
                this.sortable.destroy();
              }
            }
          }
        </script>
      </div>
    </div>
    """
  end

  defp habit_card(assigns) do
    ~H"""
    <div
      id={"habit-#{@habit.id}"}
      data-habit-id={@habit.id}
      class="relative bg-white rounded-2xl shadow-sm border border-gray-100 p-6 transition-all duration-200 hover:shadow-md"
    >
      <div class="flex items-start justify-between">
        <%!-- Drag Handle --%>
        <div class="drag-handle cursor-move p-2 -ml-2 text-gray-400 hover:text-gray-600 transition-colors touch-target">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16" />
          </svg>
        </div>

        <div class="flex items-start gap-4 flex-1">
          <%!-- Icon --%>
          <HabitComponents.habit_icon 
            icon={@habit.icon} 
            color={@habit.color} 
            size="md"
          />

          <%!-- Habit Info --%>
          <div class="flex-1 min-w-0">
            <h3 class="text-lg font-semibold text-gray-900 mb-1">
              <%= @habit.name %>
            </h3>

            <p :if={@habit.description} class="text-sm text-gray-600 mb-2">
              <%= @habit.description %>
            </p>

            <%!-- Habit Details --%>
            <div class="flex flex-wrap gap-3 text-sm text-gray-600">
              <span class="inline-flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
                <%= habit_type_label(@habit.type) %>
              </span>

              <span :if={@habit.target_value} class="inline-flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 21v-4m0 0V5a2 2 0 012-2h6.5l1 1H21l-3 6 3 6h-8.5l-1-1H5a2 2 0 00-2 2zm9-13.5V9" />
                </svg>
                Target: <%= format_target(@habit) %>
              </span>

              <span class="inline-flex items-center gap-1">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <%= schedule_label(@habit.occurrence_schedule) %>
              </span>
            </div>
          </div>
        </div>

        <%!-- Action Buttons --%>
        <div class="ml-4 flex gap-2">
          <.link
            navigate={~p"/app/habits/#{@habit.id}/edit"}
            class="p-2 text-gray-600 hover:text-blue-600 transition-colors rounded-lg hover:bg-blue-50 touch-target"
            title="Edit"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
            </svg>
          </.link>

          <button
            phx-click="delete_habit"
            phx-value-habit-id={@habit.id}
            data-confirm="Are you sure you want to delete this habit? This action cannot be undone."
            class="p-2 text-gray-600 hover:text-red-600 transition-colors rounded-lg hover:bg-red-50 touch-target"
            title="Delete"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp habit_type_label(:binary), do: "Yes/No"
  defp habit_type_label(:numeric), do: "Numeric"
  defp habit_type_label(:duration), do: "Duration"

  defp format_target(habit) do
    case habit.type do
      :numeric ->
        if habit.unit_label do
          "#{habit.target_value} #{habit.unit_label}"
        else
          "#{habit.target_value}"
        end

      :duration ->
        "#{habit.target_value} minutes"

      _ ->
        ""
    end
  end

  defp schedule_label(%{"type" => "daily"}), do: "Daily"

  defp schedule_label(%{"type" => "weekdays", "days" => days}) do
    day_names = %{1 => "Mon", 2 => "Tue", 3 => "Wed", 4 => "Thu", 5 => "Fri", 6 => "Sat", 7 => "Sun"}
    day_labels = Enum.map(days, &Map.get(day_names, &1)) |> Enum.join(", ")
    day_labels
  end

  defp schedule_label(_), do: "Custom"
end
