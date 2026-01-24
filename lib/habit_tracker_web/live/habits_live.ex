defmodule HabitTrackerWeb.HabitsLive do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Tracker

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    
    # Load all habits (active and inactive)
    habits = Tracker.list_all_habits(user)
    
    {:ok,
     socket
     |> assign(:habits, habits)
     |> assign(:filter, :all)}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    filter_atom = String.to_existing_atom(filter)
    user = socket.assigns.current_scope.user
    
    habits = case filter_atom do
      :all -> Tracker.list_all_habits(user)
      :active -> Tracker.list_active_habits(user)
      :inactive -> Tracker.list_inactive_habits(user)
    end
    
    {:noreply,
     socket
     |> assign(:habits, habits)
     |> assign(:filter, filter_atom)}
  end

  @impl true
  def handle_event("toggle_active", %{"habit-id" => habit_id}, socket) do
    habit_id = String.to_integer(habit_id)
    
    # Find the habit
    habit = Enum.find(socket.assigns.habits, &(&1.id == habit_id))
    
    if habit do
      case Tracker.update_habit(habit, %{active: !habit.active}, socket.assigns.current_scope) do
        {:ok, _updated_habit} ->
          # Reload habits with current filter
          user = socket.assigns.current_scope.user
          habits = case socket.assigns.filter do
            :all -> Tracker.list_all_habits(user)
            :active -> Tracker.list_active_habits(user)
            :inactive -> Tracker.list_inactive_habits(user)
          end
          
          {:noreply,
           socket
           |> assign(:habits, habits)
           |> put_flash(:info, "Habit #{if habit.active, do: "deactivated", else: "activated"}")}
        
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update habit")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_habit", %{"habit-id" => habit_id}, socket) do
    habit_id = String.to_integer(habit_id)
    
    # Find the habit
    habit = Enum.find(socket.assigns.habits, &(&1.id == habit_id))
    
    if habit do
      case Tracker.delete_habit(habit, socket.assigns.current_scope) do
        {:ok, _deleted_habit} ->
          # Reload habits with current filter
          user = socket.assigns.current_scope.user
          habits = case socket.assigns.filter do
            :all -> Tracker.list_all_habits(user)
            :active -> Tracker.list_active_habits(user)
            :inactive -> Tracker.list_inactive_habits(user)
          end
          
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
        # Reload habits with current filter to reflect new positions
        habits = case socket.assigns.filter do
          :all -> Tracker.list_all_habits(user)
          :active -> Tracker.list_active_habits(user)
          :inactive -> Tracker.list_inactive_habits(user)
        end
        
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
    <div class="min-h-screen bg-gradient-to-br from-indigo-50 via-purple-50 to-pink-50 dark:from-gray-900 dark:via-indigo-950 dark:to-purple-950 app-background">
      <div class="max-w-4xl mx-auto px-4 py-8 relative z-10">
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-5xl font-extrabold text-gradient">
            My Habits
          </h1>
          <.link
            navigate={~p"/app/habits/new"}
            class="px-6 py-3 bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 hover:from-indigo-700 hover:via-purple-700 hover:to-pink-700 text-white rounded-xl transition-all duration-200 font-semibold shadow-lg hover:shadow-xl spring-bounce hover-lift"
          >
            <.icon name="hero-plus" class="w-5 h-5 inline-block mr-1" />
            New Habit
          </.link>
        </div>

        <%!-- Filter Tabs --%>
        <div class="mb-8 flex space-x-3">
          <button
            phx-click="filter"
            phx-value-filter="all"
            class={[
              "filter-pill",
              if(@filter == :all, do: "active", else: "")
            ]}
          >
            All
          </button>
          <button
            phx-click="filter"
            phx-value-filter="active"
            class={[
              "filter-pill",
              if(@filter == :active, do: "active", else: "")
            ]}
          >
            Active
          </button>
          <button
            phx-click="filter"
            phx-value-filter="inactive"
            class={[
              "filter-pill",
              if(@filter == :inactive, do: "active", else: "")
            ]}
          >
            Inactive
          </button>
        </div>

        <%!-- Habits List --%>
        <div id="habits-list" phx-hook=".HabitSortable" class="space-y-4">
          <%= for habit <- @habits do %>
            <.habit_card habit={habit} />
          <% end %>

          <div :if={@habits == []} class="empty-state-enhanced">
            <svg class="empty-state-icon-enhanced text-indigo-300 dark:text-indigo-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
            </svg>
            <h2 class="empty-state-title-enhanced">
              <%= empty_message(@filter) %>
            </h2>
            <.link
              :if={@filter != :all}
              navigate={~p"/app/habits/new"}
              class="btn-primary spring-bounce"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
              </svg>
              Create Your First Habit
            </.link>
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
      class={[
        "habit-card-glass",
        !@habit.active && "opacity-60"
      ]}
    >
      <div class="flex items-start justify-between">
        <%!-- Drag Handle --%>
        <div class="drag-handle cursor-move p-2 -ml-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors">
          <.icon name="hero-bars-3" class="w-5 h-5" />
        </div>

        <div class="flex items-start space-x-3 flex-1">
          <%!-- Icon --%>
          <div 
            class="habit-icon-enhanced"
            style={"background: linear-gradient(135deg, #{@habit.color}20 0%, #{@habit.color}40 100%); color: #{@habit.color}; border: 2px solid #{@habit.color}30;"}
          >
            <%= @habit.icon %>
          </div>

          <%!-- Habit Info --%>
          <div class="flex-1 min-w-0">
            <div class="flex items-center space-x-2">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                <%= @habit.name %>
              </h3>
              <span
                :if={!@habit.active}
                class="px-2 py-0.5 text-xs font-medium bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded"
              >
                Inactive
              </span>
            </div>

            <p :if={@habit.description} class="text-sm text-gray-600 dark:text-gray-400 mt-1">
              <%= @habit.description %>
            </p>

            <%!-- Habit Details --%>
            <div class="mt-2 flex flex-wrap gap-2 text-sm text-gray-600 dark:text-gray-400">
              <span class="inline-flex items-center">
                <.icon name="hero-chart-bar" class="w-4 h-4 mr-1" />
                <%= habit_type_label(@habit.type) %>
              </span>

              <span :if={@habit.target_value} class="inline-flex items-center">
                <.icon name="hero-flag" class="w-4 h-4 mr-1" />
                Target: <%= format_target(@habit) %>
              </span>

              <span class="inline-flex items-center">
                <.icon name="hero-calendar" class="w-4 h-4 mr-1" />
                <%= schedule_label(@habit.occurrence_schedule) %>
              </span>
            </div>
          </div>
        </div>

        <%!-- Action Buttons --%>
        <div class="ml-4 flex flex-col space-y-2">
          <.link
            navigate={~p"/app/habits/#{@habit.id}/edit"}
            class="p-2 text-gray-600 dark:text-gray-400 hover:text-blue-600 dark:hover:text-blue-400 transition-all spring-bounce hover-lift rounded-lg hover:bg-blue-50 dark:hover:bg-blue-900/20"
            title="Edit"
          >
            <.icon name="hero-pencil" class="w-5 h-5" />
          </.link>

          <button
            phx-click="toggle_active"
            phx-value-habit-id={@habit.id}
            class="p-2 text-gray-600 dark:text-gray-400 hover:text-green-600 dark:hover:text-green-400 transition-all spring-bounce hover-lift rounded-lg hover:bg-green-50 dark:hover:bg-green-900/20"
            title={if @habit.active, do: "Deactivate", else: "Activate"}
          >
            <.icon
              name={if @habit.active, do: "hero-pause", else: "hero-play"}
              class="w-5 h-5"
            />
          </button>

          <button
            phx-click="delete_habit"
            phx-value-habit-id={@habit.id}
            data-confirm="Are you sure you want to delete this habit? This action cannot be undone."
            class="p-2 text-gray-600 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-400 transition-all spring-bounce hover-lift rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20"
            title="Delete"
          >
            <.icon name="hero-trash" class="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp empty_message(:all), do: "No habits yet. Create your first habit to get started!"
  defp empty_message(:active), do: "No active habits. Activate a habit or create a new one."
  defp empty_message(:inactive), do: "No inactive habits."

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
