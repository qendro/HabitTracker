defmodule HabitTrackerWeb.HabitFormLive do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Tracker
  alias HabitTracker.Tracker.HabitForm
  alias HabitTrackerWeb.HabitComponents
  import HabitTrackerWeb.HabitFormComponents

  @colors [
    "#3B82F6",
    "#10B981",
    "#F59E0B",
    "#EF4444",
    "#8B5CF6",
    "#EC4899",
    "#06B6D4",
    "#84CC16",
    "#F97316",
    "#6366F1",
    "#14B8A6",
    "#A855F7"
  ]

  @icons [
    "🏃", "💪", "📚", "💧", "🧘", "🎯", "✅", "⭐", "🔥", "💯",
    "🎨", "🎵", "📝", "💼", "🏋️", "🚴", "🏊", "🧠", "❤️", "🌟",
    "🎓", "🍎", "☕", "🌱", "🎭", "🎬", "📱", "💻", "🍕", "🥗",
    "🏠", "✈️", "🎸", "📷", "⚽", "🏀", "🎾", "🎯", "🧩", "📖"
  ]

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_scope.user

    {mode, habit, page_title} =
      case params do
        %{"id" => id} ->
          habit = Tracker.get_habit!(user, String.to_integer(id))
          {:edit, habit, "Edit Habit"}

        _ ->
          habit = HabitForm.default_habit()
          {:new, habit, "New Habit"}
      end

    changeset = HabitForm.changeset(habit, %{})
    {schedule_type, weekdays} = HabitForm.default_schedule_state(habit)

    {:ok,
     socket
     |> assign(:mode, mode)
     |> assign(:page_title, page_title)
     |> assign(:habit, habit)
     |> assign(:form, to_form(changeset, as: "habit"))
     |> assign(:schedule_type, schedule_type)
     |> assign(:weekdays, weekdays)
     |> assign(:show_advanced, show_advanced_default?(habit))
     |> assign(:show_picker, false)
     |> assign(:colors, @colors)
     |> assign(:icons, @icons)}
  end

  @impl true
  def handle_event("validate", %{"habit" => habit_params}, socket) do
    {:noreply, update_form(socket, habit_params, :validate)}
  end

  @impl true
  def handle_event("save", %{"habit" => habit_params}, socket) do
    params = merge_params(socket.assigns.form.params, habit_params)
    {schedule_type, weekdays} = schedule_state(params, socket)
    params = Map.put(params, "schedule_type", schedule_type)
    params = Map.put(params, "weekdays", weekdays)

    changeset = HabitForm.changeset(socket.assigns.habit, params)

    if changeset.valid? do
      user = socket.assigns.current_scope.user
      attrs = HabitForm.to_habit_attrs(socket.assigns.habit, params)

      case socket.assigns.mode do
        :new ->
          case Tracker.create_habit(user, attrs, socket.assigns.current_scope) do
            {:ok, _habit} ->
              {:noreply,
               socket
               |> put_flash(:info, "Habit created successfully")
               |> push_navigate(to: ~p"/app/habits")}

            {:error, :readonly_mode} ->
              {:noreply,
               socket
               |> put_flash(:error, "Read-only mode enabled. Habits cannot be created.")}

            {:error, %Ecto.Changeset{} = error_changeset} ->
              {:noreply,
               assign_form(
                 socket,
                 Map.put(error_changeset, :action, :insert),
                 schedule_type,
                 weekdays
               )}
          end

        :edit ->
          case Tracker.update_habit(socket.assigns.habit, attrs, socket.assigns.current_scope) do
            {:ok, _habit} ->
              {:noreply,
               socket
               |> put_flash(:info, "Habit updated successfully")
               |> push_navigate(to: ~p"/app/habits")}

            {:error, :readonly_mode} ->
              {:noreply,
               socket
               |> put_flash(:error, "Read-only mode enabled. Habits cannot be updated.")}

            {:error, %Ecto.Changeset{} = error_changeset} ->
              {:noreply,
               assign_form(
                 socket,
                 Map.put(error_changeset, :action, :insert),
                 schedule_type,
                 weekdays
               )}
          end
      end
    else
      {:noreply,
       assign_form(socket, Map.put(changeset, :action, :insert), schedule_type, weekdays)}
    end
  end

  @impl true
  def handle_event("toggle_picker", _params, socket) do
    {:noreply, assign(socket, :show_picker, !socket.assigns.show_picker)}
  end

  @impl true
  def handle_event("pick_icon", %{"icon" => icon}, socket) do
    socket = update_form(socket, %{"icon" => icon}, :validate)
    {:noreply, socket}
  end

  @impl true
  def handle_event("pick_color", %{"color" => color}, socket) do
    socket = update_form(socket, %{"color" => color}, :validate)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :show_advanced, !socket.assigns.show_advanced)}
  end

  defp update_form(socket, habit_params, action) do
    params = merge_params(socket.assigns.form.params, habit_params)
    {schedule_type, weekdays} = schedule_state(params, socket)
    params = Map.put(params, "schedule_type", schedule_type)
    params = Map.put(params, "weekdays", weekdays)

    changeset =
      socket.assigns.habit
      |> HabitForm.changeset(params)
      |> Map.put(:action, action)

    assign_form(socket, changeset, schedule_type, weekdays)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset, schedule_type, weekdays) do
    show_advanced = socket.assigns.show_advanced || advanced_errors?(changeset)

    socket
    |> assign(:form, to_form(changeset, as: "habit"))
    |> assign(:schedule_type, schedule_type)
    |> assign(:weekdays, weekdays)
    |> assign(:show_advanced, show_advanced)
  end

  defp merge_params(existing_params, new_params) do
    existing_params = existing_params || %{}
    Map.merge(existing_params, new_params)
  end

  defp schedule_state(params, socket) do
    schedule_type =
      params
      |> Map.get("schedule_type")
      |> HabitForm.normalize_schedule_type()
      |> fallback_schedule_type(socket)

    weekdays =
      if Map.has_key?(params, "weekdays") do
        HabitForm.normalize_weekdays(Map.get(params, "weekdays"))
      else
        socket.assigns.weekdays
      end

    {schedule_type, weekdays}
  end

  defp fallback_schedule_type(nil, socket) do
    socket.assigns.schedule_type || "daily"
  end

  defp fallback_schedule_type(schedule_type, _socket), do: schedule_type

  defp form_value(form, field, fallback) do
    case form.source do
      %Ecto.Changeset{} = changeset ->
        Ecto.Changeset.get_field(changeset, field) || fallback

      _ ->
        form[field].value || fallback
    end
  end

  defp field_errors(form, field) do
    errors = if form.source, do: form.source.errors, else: []

    errors
    |> Enum.filter(fn {error_field, _} -> error_field == field end)
    |> Enum.map(fn {_field, error} -> translate_error(error) end)
  end

  defp form_errors(form) do
    errors = if form.source, do: form.source.errors, else: []

    Enum.map(errors, fn {field, error} ->
      {field, translate_error(error)}
    end)
  end

  defp humanize_field(field) when is_atom(field), do: Phoenix.Naming.humanize(field)
  defp humanize_field(field) when is_binary(field), do: Phoenix.Naming.humanize(field)

  defp advanced_errors?(changeset) do
    Enum.any?(changeset.errors, fn {field, _} ->
      field in [:goal_horizon, :frequency_goal, :description]
    end)
  end

  defp show_advanced_default?(habit) do
    habit.description not in [nil, ""] or
      habit.goal_horizon not in [nil, :daily] or
      not is_nil(habit.frequency_goal)
  end

end
