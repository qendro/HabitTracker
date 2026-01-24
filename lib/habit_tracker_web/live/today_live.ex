defmodule HabitTrackerWeb.TodayLive do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Tracker
  alias HabitTrackerWeb.HabitComponents

  @impl true
  def mount(params, session, socket) do
    # Get the date from params or default to today
    selected_date = parse_date(params["date"], socket.assigns.current_scope.user.timezone)
    
    # Load habits for the selected date
    habits_with_progress = Tracker.today_dashboard(socket.assigns.current_scope.user, selected_date)
    
    # Calculate completion summary
    total = length(habits_with_progress)
    completed = Enum.count(habits_with_progress, & &1.is_complete)
    
    # Check if viewing today
    today = today_in_timezone(socket.assigns.current_scope.user.timezone)
    is_today = Date.compare(selected_date, today) == :eq
    is_future = Date.compare(selected_date, today) == :gt

    # Check for readonly mode from session (admin impersonation)
    readonly_mode = Map.get(session, "readonly_mode", false)

    {:ok,
     socket
     |> assign(:selected_date, selected_date)
     |> assign(:habits_with_progress, habits_with_progress)
     |> assign(:completion_summary, %{completed: completed, total: total})
     |> assign(:is_today, is_today)
     |> assign(:is_future, is_future)
     |> assign(:readonly_mode, readonly_mode)
     |> assign(:timezone, socket.assigns.current_scope.user.timezone)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    selected_date = parse_date(params["date"], socket.assigns.current_scope.user.timezone)
    
    # Reload habits if date changed
    if selected_date != socket.assigns.selected_date do
      habits_with_progress = Tracker.today_dashboard(socket.assigns.current_scope.user, selected_date)
      
      total = length(habits_with_progress)
      completed = Enum.count(habits_with_progress, & &1.is_complete)
      
      today = today_in_timezone(socket.assigns.current_scope.user.timezone)
      is_today = Date.compare(selected_date, today) == :eq
      is_future = Date.compare(selected_date, today) == :gt

      {:noreply,
       socket
       |> assign(:selected_date, selected_date)
       |> assign(:habits_with_progress, habits_with_progress)
       |> assign(:completion_summary, %{completed: completed, total: total})
       |> assign(:is_today, is_today)
       |> assign(:is_future, is_future)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_day", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, -1)
    {:noreply, push_patch(socket, to: ~p"/app/day/#{Date.to_iso8601(new_date)}")}
  end

  @impl true
  def handle_event("next_day", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, 1)
    {:noreply, push_patch(socket, to: ~p"/app/day/#{Date.to_iso8601(new_date)}")}
  end

  @impl true
  def handle_event("back_to_today", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/app/today")}
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        {:noreply, push_patch(socket, to: ~p"/app/day/#{Date.to_iso8601(date)}")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid date format")}
    end
  end

  @impl true
  def handle_event("swipe_left", _params, socket) do
    # Swipe left = next day
    new_date = Date.add(socket.assigns.selected_date, 1)
    {:noreply, push_patch(socket, to: ~p"/app/day/#{Date.to_iso8601(new_date)}")}
  end

  @impl true
  def handle_event("swipe_right", _params, socket) do
    # Swipe right = previous day
    new_date = Date.add(socket.assigns.selected_date, -1)
    {:noreply, push_patch(socket, to: ~p"/app/day/#{Date.to_iso8601(new_date)}")}
  end

  @impl true
  def handle_event("toggle_habit", %{"habit-id" => habit_id}, socket) do
    # Check readonly mode
    if readonly_mode?(socket) do
      {:noreply, put_flash(socket, :error, "Cannot modify habits in read-only mode")}
    else
      habit_id = String.to_integer(habit_id)
      
      # Find the habit
      habit_with_progress = Enum.find(socket.assigns.habits_with_progress, &(&1.habit.id == habit_id))
      
      if habit_with_progress do
        habit = habit_with_progress.habit
        log = habit_with_progress.log
        
        # Toggle status: not_complete -> complete, complete -> not_complete
        new_status = if log && log.status == :complete, do: :not_complete, else: :complete
        
        # Log the habit
        case Tracker.log_habit(habit, socket.assigns.selected_date, %{status: new_status}, socket.assigns.current_scope) do
          {:ok, _log} ->
            # Reload habits to get accurate data
            habits_with_progress = Tracker.today_dashboard(socket.assigns.current_scope.user, socket.assigns.selected_date)
            
            total = length(habits_with_progress)
            completed = Enum.count(habits_with_progress, & &1.is_complete)
            
            {:noreply,
             socket
             |> assign(:habits_with_progress, habits_with_progress)
             |> assign(:completion_summary, %{completed: completed, total: total})
             |> put_flash(:info, "Habit updated")}
          
          {:error, _changeset} ->
            # Rollback - reload from database
            habits_with_progress = Tracker.today_dashboard(socket.assigns.current_scope.user, socket.assigns.selected_date)
            
            total = length(habits_with_progress)
            completed = Enum.count(habits_with_progress, & &1.is_complete)
            
            {:noreply, 
             socket
             |> assign(:habits_with_progress, habits_with_progress)
             |> assign(:completion_summary, %{completed: completed, total: total})
             |> put_flash(:error, "Failed to update habit")}
        end
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("log_value", %{"habit-id" => habit_id, "value" => value}, socket) do
    # Check readonly mode
    if readonly_mode?(socket) do
      {:noreply, put_flash(socket, :error, "Cannot modify habits in read-only mode")}
    else
      habit_id = String.to_integer(habit_id)
      
      # Find the habit
      habit_with_progress = Enum.find(socket.assigns.habits_with_progress, &(&1.habit.id == habit_id))
      
      if habit_with_progress do
        habit = habit_with_progress.habit
        
        # Parse value based on habit type
        attrs = case habit.type do
          :numeric ->
            case Decimal.parse(value) do
              {decimal_value, _} -> %{numeric_value: decimal_value}
              :error -> nil
            end
          
          :duration ->
            case Integer.parse(value) do
              {int_value, _} -> %{duration_minutes: int_value}
              :error -> nil
            end
          
          _ -> nil
        end
        
        if attrs do
          # Log the habit
          case Tracker.log_habit(habit, socket.assigns.selected_date, attrs, socket.assigns.current_scope) do
            {:ok, _log} ->
              # Reload habits to get accurate data
              habits_with_progress = Tracker.today_dashboard(socket.assigns.current_scope.user, socket.assigns.selected_date)
              
              total = length(habits_with_progress)
              completed = Enum.count(habits_with_progress, & &1.is_complete)
              
              {:noreply,
               socket
               |> assign(:habits_with_progress, habits_with_progress)
               |> assign(:completion_summary, %{completed: completed, total: total})
               |> put_flash(:info, "Value logged")}
            
            {:error, _changeset} ->
              # Rollback - reload from database
              habits_with_progress = Tracker.today_dashboard(socket.assigns.current_scope.user, socket.assigns.selected_date)
              
              total = length(habits_with_progress)
              completed = Enum.count(habits_with_progress, & &1.is_complete)
              
              {:noreply,
               socket
               |> assign(:habits_with_progress, habits_with_progress)
               |> assign(:completion_summary, %{completed: completed, total: total})
               |> put_flash(:error, "Failed to log value")}
          end
        else
          {:noreply, put_flash(socket, :error, "Invalid value")}
        end
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 via-blue-50/30 to-cyan-50/30 app-container" id="today-container" phx-hook=".SwipeDetector">
      <%!-- Subtle animated background blobs --%>
      <div class="fixed inset-0 overflow-hidden pointer-events-none">
        <div class="absolute top-0 right-0 w-96 h-96 bg-gradient-to-br from-blue-200/20 to-cyan-200/20 rounded-full blur-3xl animate-blob"></div>
        <div class="absolute bottom-0 left-0 w-80 h-80 bg-gradient-to-tr from-indigo-200/20 to-blue-200/20 rounded-full blur-3xl animate-blob animation-delay-2000"></div>
        <div class="absolute top-1/2 left-1/2 w-72 h-72 bg-gradient-to-br from-cyan-200/20 to-teal-200/20 rounded-full blur-3xl animate-blob animation-delay-4000"></div>
      </div>

      <div class="relative max-w-4xl mx-auto px-4 py-8">
        <%!-- Skip Navigation Link for Accessibility --%>
        <a href="#main-content" class="skip-nav">
          Skip to main content
        </a>

        <%!-- Date Navigation --%>
        <HabitComponents.date_navigator
          selected_date={@selected_date}
          is_today={@is_today}
          timezone={@timezone}
        />

        <%!-- Completion Summary --%>
        <div class="mb-6">
          <HabitComponents.completion_summary
            completed={@completion_summary.completed}
            total={@completion_summary.total}
          />
        </div>

        <%!-- Habit Cards --%>
        <div id="main-content" class="space-y-4" role="main" aria-label="Habit list">
          <%= for habit_with_progress <- @habits_with_progress do %>
            <HabitComponents.habit_card
              habit={habit_with_progress.habit}
              log={habit_with_progress.log}
              streak={habit_with_progress.streak}
              is_complete={habit_with_progress.is_complete}
              progress={habit_with_progress.progress}
              is_future={@is_future}
              readonly={@readonly_mode}
            />
          <% end %>

          <div :if={@habits_with_progress == []} class="relative bg-white rounded-2xl shadow-sm border-2 border-dashed border-gray-200 p-16 text-center">
            <div class="flex flex-col items-center">
              <div class="w-24 h-24 bg-gradient-to-br from-blue-100 to-cyan-100 rounded-full flex items-center justify-center mb-6">
                <svg class="w-12 h-12 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-gray-900 mb-2">No habits scheduled for this day</h2>
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
      </div>
    </div>

    <%!-- SwipeDetector JavaScript Hook --%>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".SwipeDetector">
      export default {
        mounted() {
          let touchStartX = 0;
          let touchEndX = 0;
          const swipeThreshold = 50;

          this.el.addEventListener('touchstart', (e) => {
            touchStartX = e.changedTouches[0].screenX;
          }, { passive: true });

          this.el.addEventListener('touchend', (e) => {
            touchEndX = e.changedTouches[0].screenX;
            this.handleSwipe();
          }, { passive: true });

          this.handleSwipe = () => {
            const swipeDistance = touchEndX - touchStartX;
            
            if (Math.abs(swipeDistance) >= swipeThreshold) {
              if (swipeDistance > 0) {
                this.pushEvent("swipe_right", {});
              } else {
                this.pushEvent("swipe_left", {});
              }
            }
          };
        }
      }
    </script>
    """
  end

  defp parse_date(nil, timezone), do: today_in_timezone(timezone)
  
  defp parse_date(date_string, _timezone) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> Date.utc_today()
    end
  end

  defp today_in_timezone(timezone) do
    case DateTime.shift_zone(DateTime.utc_now(:second), timezone) do
      {:ok, shifted} -> DateTime.to_date(shifted)
      _ -> DateTime.utc_now(:second) |> DateTime.to_date()
    end
  end

  # Check if in readonly mode (admin impersonation)
  defp readonly_mode?(socket) do
    Map.get(socket.assigns, :readonly_mode, false)
  end
end
