defmodule HabitTracker.Tracker do
  @moduledoc """
  The Tracker context.
  """

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias HabitTracker.Accounts
  alias HabitTracker.Accounts.User
  alias HabitTracker.Repo
  alias HabitTracker.Tracker.{Habit, HabitLog}

  @weekday_map %{
    "monday" => 1,
    "mon" => 1,
    "tuesday" => 2,
    "tue" => 2,
    "wednesday" => 3,
    "wed" => 3,
    "thursday" => 4,
    "thu" => 4,
    "friday" => 5,
    "fri" => 5,
    "saturday" => 6,
    "sat" => 6,
    "sunday" => 7,
    "sun" => 7
  }

  # Helper to check if readonly mode is active
  defp check_readonly_mode(scope) do
    if Map.get(scope, :readonly_mode, false) do
      {:error, :readonly_mode}
    else
      :ok
    end
  end

  def create_habit(%User{} = user, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      create_habit_impl(user, attrs)
    end
  end

  defp create_habit_impl(%User{} = user, attrs) do
    attrs =
      if Map.has_key?(attrs, "position") or Map.has_key?(attrs, :position) do
        attrs
      else
        if has_string_keys?(attrs) do
          Map.put(attrs, "position", next_position(user.id))
        else
          Map.put(attrs, :position, next_position(user.id))
        end
      end

    %Habit{user_id: user.id}
    |> Habit.changeset(attrs)
    |> Repo.insert()
  end

  def update_habit(%Habit{} = habit, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      update_habit_impl(habit, attrs)
    end
  end

  defp update_habit_impl(%Habit{} = habit, attrs) do
    habit
    |> Habit.changeset(attrs)
    |> Repo.update()
  end

  def delete_habit(%Habit{} = habit, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      delete_habit_impl(habit)
    end
  end

  defp delete_habit_impl(%Habit{} = habit) do
    habit
    |> Habit.soft_delete_changeset()
    |> Repo.update()
  end

  def list_active_habits(%User{} = user) do
    Habit
    |> where([h], h.user_id == ^user.id and h.active and is_nil(h.deleted_at))
    |> order_by([h], asc: h.position, asc: h.id)
    |> Repo.all()
  end

  def list_all_habits(%User{} = user) do
    Habit
    |> where([h], h.user_id == ^user.id and is_nil(h.deleted_at))
    |> order_by([h], asc: h.position, asc: h.id)
    |> Repo.all()
  end

  def list_inactive_habits(%User{} = user) do
    Habit
    |> where([h], h.user_id == ^user.id and not h.active and is_nil(h.deleted_at))
    |> order_by([h], asc: h.position, asc: h.id)
    |> Repo.all()
  end

  def get_habit!(%User{} = user, id) do
    Habit
    |> where([h], h.user_id == ^user.id and h.id == ^id and is_nil(h.deleted_at))
    |> Repo.one!()
  end

  def get_logs_for_date(%User{} = user, %Date{} = local_date) do
    HabitLog
    |> where([l], l.user_id == ^user.id and l.local_date == ^local_date)
    |> Repo.all()
  end

  def get_log(%Habit{} = habit, %Date{} = local_date) do
    Repo.get_by(HabitLog, habit_id: habit.id, local_date: local_date)
  end

  def log_habit(%Habit{} = habit, local_date, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope),
         {:ok, local_date} <- normalize_local_date(habit, local_date) do
      log_habit_impl(habit, local_date, attrs)
    end
  end

  defp log_habit_impl(%Habit{} = habit, local_date, attrs) do
    habit_log =
      Repo.get_by(HabitLog,
        habit_id: habit.id,
        local_date: local_date
      )

    with {:ok, normalized_attrs} <- normalize_log_attrs(habit, attrs, habit_log) do
      case normalized_attrs do
        :delete ->
          delete_log_for_date(habit, local_date)

        attrs ->
          (habit_log ||
             %HabitLog{habit_id: habit.id, user_id: habit.user_id, local_date: local_date})
          |> HabitLog.changeset(attrs)
          |> apply_log_matrix(habit)
          |> Repo.insert_or_update()
      end
    end
  end

  def update_habit_log(%HabitLog{} = log, attrs, scope \\ %{}) do
    with :ok <- check_readonly_mode(scope) do
      update_habit_log_impl(log, attrs)
    end
  end

  defp update_habit_log_impl(%HabitLog{} = log, attrs) do
    habit = Repo.get!(Habit, log.habit_id)

    with {:ok, normalized_attrs} <- normalize_log_attrs(habit, attrs, log) do
      case normalized_attrs do
        :delete ->
          Repo.delete(log)

        attrs ->
          log
          |> HabitLog.changeset(attrs)
          |> apply_log_matrix(habit)
          |> Repo.update()
      end
    end
  end

  def is_scheduled?(%Habit{} = habit, %Date{} = date) do
    schedule = habit.occurrence_schedule || %{}

    scheduled_for_date?(schedule_type(schedule), schedule_days(schedule), date)
  end

  def scheduled_dates(%Habit{} = habit, %Date.Range{} = range) do
    range
    |> Enum.filter(&is_scheduled?(habit, &1))
  end

  def scheduled_dates(%Habit{} = habit, {from_date, to_date})
      when is_struct(from_date, Date) and is_struct(to_date, Date) do
    if Date.compare(from_date, to_date) == :gt do
      []
    else
      Date.range(from_date, to_date)
      |> Enum.filter(&is_scheduled?(habit, &1))
    end
  end

  def calculate_streak(%Habit{} = habit, as_of_date \\ nil) do
    habit = Repo.preload(habit, :user)
    schedule = habit.occurrence_schedule || %{}
    schedule_type = schedule_type(schedule)
    schedule_days = schedule_days(schedule)

    if schedule_type != "daily" and schedule_days == [] do
      0
    else
      today = today_in_user_timezone(habit)

      effective_as_of =
        case normalize_local_date(habit, as_of_date) do
          {:ok, date} -> date
          _ -> today
        end

      effective_date =
        case Date.compare(effective_as_of, today) do
          :gt -> today
          _ -> effective_as_of
        end

      completed_dates = completed_log_dates(habit.id, effective_date)

      if MapSet.size(completed_dates) == 0 do
        0
      else
        min_completed =
          completed_dates
          |> MapSet.to_list()
          |> Enum.min_by(&Date.to_erl/1)

        count_streak(
          effective_date,
          min_completed,
          completed_dates,
          schedule_type,
          schedule_days,
          0
        )
      end
    end
  end

  @doc """
  Calculate the completion rate for a habit over a given period.

  Returns a float between 0.0 and 1.0 representing the percentage of scheduled
  occurrences that were completed.

  ## Parameters

    * `habit` - The habit to calculate completion rate for
    * `period` - Either `:this_week` or `:this_month`
    * `timezone` - The IANA timezone string to use for date boundaries

  ## Examples

      iex> completion_rate(habit, :this_week, "America/New_York")
      0.75

      iex> completion_rate(habit, :this_month, "UTC")
      0.5

  """
  def completion_rate(%Habit{} = habit, period, timezone) when period in [:this_week, :this_month] do
    {start_date, end_date} = period_to_date_range(period, timezone)

    scheduled_dates = scheduled_dates(habit, {start_date, end_date})
    total_scheduled = length(scheduled_dates)

    if total_scheduled > 0 do
      completed =
        from(log in HabitLog,
          where: log.habit_id == ^habit.id,
          where: log.local_date >= ^start_date,
          where: log.local_date <= ^end_date,
          where: log.status == :complete,
          select: count(log.id)
        )
        |> Repo.one()

      completed / total_scheduled
    else
      0.0
    end
  end

  @doc """
  Calculate progress toward a habit's frequency goal for the current period.

  Returns a tuple {completed, target} where:
    * completed - number of completions in the current period
    * target - the frequency_goal value from the habit

  The period is determined by the habit's goal_horizon:
    * :weekly - current week (Monday to Sunday)
    * :monthly - current month
    * :yearly - current year
    * :daily - returns {0, 0} as daily goals don't have frequency targets

  ## Parameters

    * `habit` - The habit to calculate frequency progress for
    * `timezone` - The IANA timezone string to use for date boundaries

  ## Examples

      iex> frequency_progress(habit, "America/New_York")
      {3, 5}  # 3 completions out of 5 goal for the week

      iex> frequency_progress(habit, "UTC")
      {10, 20}  # 10 completions out of 20 goal for the month

  """
  def frequency_progress(%Habit{goal_horizon: :daily} = _habit, _timezone) do
    # Daily goals don't have frequency targets
    {0, 0}
  end

  def frequency_progress(%Habit{} = habit, timezone) do
    target = habit.frequency_goal || 0
    
    {start_date, end_date} = goal_horizon_to_date_range(habit.goal_horizon, timezone)

    completed =
      from(log in HabitLog,
        where: log.habit_id == ^habit.id,
        where: log.local_date >= ^start_date,
        where: log.local_date <= ^end_date,
        where: log.status == :complete,
        select: count(log.id)
      )
      |> Repo.one()

    {completed, target}
  end

  @doc """
  Load habits for the today dashboard with sparse storage query.

  Returns a list of habits scheduled for the given date with their logs and progress.
  Uses LEFT JOIN on habit_logs so missing logs are treated as implicit not_complete.

  ## Parameters

    * `user` - The user to load habits for
    * `local_date` - The date to load habits for (defaults to today in user's timezone)

  ## Returns

  A list of maps with the following structure:
    * `:habit` - The habit struct
    * `:log` - The habit log for the date (nil if no log exists)
    * `:streak` - Current streak count
    * `:is_complete` - Boolean indicating if the habit is complete
    * `:progress` - Progress information (varies by habit type)

  """
  def today_dashboard(%User{} = user, local_date \\ nil) do
    local_date = local_date || today_in_timezone(user.timezone)

    # Load all active habits
    habits =
      from(h in Habit,
        where: h.user_id == ^user.id,
        where: h.active == true,
        where: is_nil(h.deleted_at),
        order_by: [asc: h.position, asc: h.id]
      )
      |> Repo.all()

    # Load logs for the selected date
    logs =
      from(log in HabitLog,
        where: log.user_id == ^user.id,
        where: log.local_date == ^local_date
      )
      |> Repo.all()
      |> Map.new(&{&1.habit_id, &1})

    # Filter to only scheduled habits and enrich with progress
    habits
    |> Enum.filter(&is_scheduled?(&1, local_date))
    |> Enum.map(&enrich_with_progress(&1, local_date, logs))
  end

  defp enrich_with_progress(habit, local_date, logs) do
    # Get the log for this date (will be nil if no log exists - sparse storage)
    log = Map.get(logs, habit.id)
    
    # Calculate streak
    streak = calculate_streak(habit, local_date)
    
    # Determine if complete (missing log = not complete)
    is_complete = log && log.status == :complete
    
    # Calculate progress based on habit type
    progress = calculate_progress(habit, log)

    %{
      habit: habit,
      log: log,
      streak: streak,
      is_complete: is_complete,
      progress: progress
    }
  end

  defp calculate_progress(%Habit{type: :binary}, log) do
    %{
      type: :binary,
      status: if(log, do: log.status, else: :not_complete)
    }
  end

  defp calculate_progress(%Habit{type: :numeric, target_value: target} = habit, log) do
    current = if log && log.numeric_value, do: log.numeric_value, else: 0
    
    %{
      type: :numeric,
      current: current,
      target: target,
      unit: habit.unit_label,
      percentage: calculate_percentage(current, target),
      status: if(log, do: log.status, else: :not_complete)
    }
  end

  defp calculate_progress(%Habit{type: :duration, target_value: target} = habit, log) do
    current = if log && log.duration_minutes, do: log.duration_minutes, else: 0
    
    %{
      type: :duration,
      current: current,
      target: target,
      unit: habit.unit_label || "minutes",
      percentage: calculate_percentage(current, target),
      status: if(log, do: log.status, else: :not_complete)
    }
  end

  defp calculate_percentage(current, target) when is_integer(current) and is_integer(target) do
    if target > 0 do
      min(100, div(current * 100, target))
    else
      0
    end
  end

  defp calculate_percentage(_current, _target), do: 0

  def reorder_habits(%User{} = user, habit_ids) when is_list(habit_ids) do
    case Repo.transact(fn ->
           habit_ids
           |> Enum.with_index()
           |> Enum.reduce_while(:ok, fn {habit_id, position}, _ ->
             {count, _} =
               Repo.update_all(
                 from(h in Habit,
                   where: h.id == ^habit_id and h.user_id == ^user.id and is_nil(h.deleted_at)
                 ),
                 set: [position: position]
               )

             if count == 1, do: {:cont, :ok}, else: {:halt, {:error, :not_found}}
           end)
           |> case do
             :ok -> {:ok, :ok}
             {:error, reason} -> {:error, reason}
           end
         end) do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp next_position(user_id) do
    Habit
    |> where([h], h.user_id == ^user_id)
    |> select([h], max(h.position))
    |> Repo.one()
    |> case do
      nil -> 0
      max_pos -> max_pos + 1
    end
  end

  defp normalize_log_attrs(_habit, attrs, log) when is_map(attrs) do
    {status_present?, status} = fetch_attr(attrs, :status)
    {numeric_present?, numeric_value} = fetch_attr(attrs, :numeric_value)
    {duration_present?, duration_minutes} = fetch_attr(attrs, :duration_minutes)
    {notes_present?, notes} = fetch_attr(attrs, :notes)

    status = normalize_status(status)
    numeric_value = parse_int(numeric_value)
    duration_minutes = parse_int(duration_minutes)
    notes = normalize_notes(notes)

    if status == :not_complete and is_nil(numeric_value) and is_nil(duration_minutes) and
         is_nil(notes) do
      {:ok, :delete}
    else
      attrs =
        %{}
        |> maybe_put(:status, status_present?, status)
        |> maybe_put(:numeric_value, numeric_present?, numeric_value)
        |> maybe_put(:duration_minutes, duration_present?, duration_minutes)
        |> maybe_put(:notes, notes_present?, notes)
        |> maybe_put_default_status(status_present?, log, notes, numeric_value, duration_minutes)

      if map_size(attrs) == 0 do
        {:error, :invalid}
      else
        {:ok, attrs}
      end
    end
  end

  defp normalize_log_attrs(_habit, _attrs, _log), do: {:error, :invalid}

  defp apply_log_matrix(changeset, %Habit{type: :binary}) do
    status = get_field(changeset, :status)
    numeric_value = get_field(changeset, :numeric_value)
    duration_minutes = get_field(changeset, :duration_minutes)
    notes = get_field(changeset, :notes)

    changeset =
      cond do
        is_nil(status) and (notes || numeric_value || duration_minutes) ->
          put_change(changeset, :status, :planned)

        true ->
          changeset
      end

    status = get_field(changeset, :status)

    changeset
    |> validate_status_present(status)
    |> validate_binary_values(numeric_value, duration_minutes)
    |> validate_binary_status(status)
  end

  defp apply_log_matrix(changeset, %Habit{type: :numeric, target_value: target_value}) do
    status = get_field(changeset, :status)
    numeric_value = get_field(changeset, :numeric_value)
    duration_minutes = get_field(changeset, :duration_minutes)
    notes = get_field(changeset, :notes)

    changeset =
      cond do
        is_nil(status) and (notes || numeric_value || duration_minutes) ->
          put_change(changeset, :status, :planned)

        true ->
          changeset
      end

    status = get_field(changeset, :status)
    numeric_value = get_field(changeset, :numeric_value)

    changeset
    |> validate_status_present(status)
    |> validate_numeric_values(numeric_value, duration_minutes)
    |> apply_numeric_status(status, numeric_value, target_value)
  end

  defp apply_log_matrix(changeset, %Habit{type: :duration, target_value: target_value}) do
    status = get_field(changeset, :status)
    numeric_value = get_field(changeset, :numeric_value)
    duration_minutes = get_field(changeset, :duration_minutes)
    notes = get_field(changeset, :notes)

    changeset =
      cond do
        is_nil(status) and (notes || numeric_value || duration_minutes) ->
          put_change(changeset, :status, :planned)

        true ->
          changeset
      end

    status = get_field(changeset, :status)
    duration_minutes = get_field(changeset, :duration_minutes)

    changeset
    |> validate_status_present(status)
    |> validate_duration_values(numeric_value, duration_minutes)
    |> apply_duration_status(status, duration_minutes, target_value)
  end

  defp validate_status_present(changeset, status) do
    if is_nil(status) do
      add_error(changeset, :status, "can't be blank")
    else
      changeset
    end
  end

  defp validate_binary_values(changeset, numeric_value, duration_minutes) do
    if is_nil(numeric_value) and is_nil(duration_minutes) do
      changeset
    else
      changeset
      |> add_error(:numeric_value, "must be empty for binary habits")
      |> add_error(:duration_minutes, "must be empty for binary habits")
    end
  end

  defp validate_binary_status(changeset, status) do
    if status in [:planned, :complete] do
      changeset
    else
      add_error(changeset, :status, "must be planned or complete for binary habits")
    end
  end

  defp validate_numeric_values(changeset, _numeric_value, duration_minutes) do
    cond do
      not is_nil(duration_minutes) ->
        add_error(changeset, :duration_minutes, "is not allowed for numeric habits")

      true ->
        changeset
    end
  end

  defp validate_duration_values(changeset, numeric_value, _duration_minutes) do
    cond do
      not is_nil(numeric_value) ->
        add_error(changeset, :numeric_value, "is not allowed for duration habits")

      true ->
        changeset
    end
  end

  defp apply_numeric_status(changeset, status, numeric_value, target_value) do
    cond do
      is_nil(numeric_value) ->
        if status == :complete do
          add_error(changeset, :numeric_value, "is required to complete numeric habits")
        else
          changeset
        end

      numeric_value >= target_value ->
        put_change(changeset, :status, :complete)

      true ->
        put_change(changeset, :status, :planned)
    end
  end

  defp apply_duration_status(changeset, status, duration_minutes, target_value) do
    cond do
      is_nil(duration_minutes) ->
        if status == :complete do
          add_error(changeset, :duration_minutes, "is required to complete duration habits")
        else
          changeset
        end

      duration_minutes >= target_value ->
        put_change(changeset, :status, :complete)

      true ->
        put_change(changeset, :status, :planned)
    end
  end

  defp schedule_type(%{"type" => type}), do: normalize_schedule_type(type)
  defp schedule_type(%{type: type}), do: normalize_schedule_type(type)
  defp schedule_type(_), do: nil

  defp normalize_schedule_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_schedule_type(type) when is_binary(type), do: String.downcase(type)
  defp normalize_schedule_type(_), do: nil

  defp schedule_days(schedule) do
    days =
      Map.get(schedule, "days") ||
        Map.get(schedule, :days) ||
        schedule_day_flags(schedule)

    days
    |> List.wrap()
    |> Enum.map(&normalize_weekday/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp schedule_day_flags(schedule) when is_map(schedule) do
    schedule
    |> Enum.flat_map(fn {key, value} ->
      if value == true do
        [normalize_weekday(key)]
      else
        []
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp schedule_day_flags(_), do: []

  defp normalize_weekday(day) when is_integer(day) and day in 1..7, do: day

  defp normalize_weekday(day) when is_atom(day),
    do: day |> Atom.to_string() |> normalize_weekday()

  defp normalize_weekday(day) when is_binary(day), do: Map.get(@weekday_map, String.downcase(day))
  defp normalize_weekday(_), do: nil

  defp scheduled_for_date?(schedule_type, schedule_days, date) do
    cond do
      schedule_type == "daily" ->
        true

      schedule_type in ["weekdays", "weekly"] ->
        Date.day_of_week(date) in schedule_days

      schedule_type in [nil, ""] and schedule_days != [] ->
        Date.day_of_week(date) in schedule_days

      true ->
        false
    end
  end

  defp completed_log_dates(habit_id, effective_date) do
    HabitLog
    |> where(
      [l],
      l.habit_id == ^habit_id and l.status == :complete and l.local_date <= ^effective_date
    )
    |> select([l], l.local_date)
    |> Repo.all()
    |> MapSet.new()
  end

  defp count_streak(current_date, min_date, completed_dates, schedule_type, schedule_days, streak) do
    cond do
      Date.compare(current_date, min_date) == :lt ->
        streak

      scheduled_for_date?(schedule_type, schedule_days, current_date) ->
        if MapSet.member?(completed_dates, current_date) do
          count_streak(
            Date.add(current_date, -1),
            min_date,
            completed_dates,
            schedule_type,
            schedule_days,
            streak + 1
          )
        else
          streak
        end

      true ->
        count_streak(
          Date.add(current_date, -1),
          min_date,
          completed_dates,
          schedule_type,
          schedule_days,
          streak
        )
    end
  end

  defp today_in_user_timezone(habit) do
    timezone = habit_timezone(habit)

    case DateTime.shift_zone(DateTime.utc_now(:second), timezone) do
      {:ok, shifted} -> DateTime.to_date(shifted)
      _ -> DateTime.utc_now(:second) |> DateTime.to_date()
    end
  end

  defp period_to_date_range(:this_week, timezone) do
    today = today_in_timezone(timezone)
    # ISO week starts on Monday (day 1)
    day_of_week = Date.day_of_week(today)
    start_of_week = Date.add(today, -(day_of_week - 1))
    end_of_week = Date.add(start_of_week, 6)

    {start_of_week, end_of_week}
  end

  defp period_to_date_range(:this_month, timezone) do
    today = today_in_timezone(timezone)
    start_of_month = %{today | day: 1}
    end_of_month = Date.end_of_month(today)

    {start_of_month, end_of_month}
  end

  defp goal_horizon_to_date_range(:weekly, timezone) do
    today = today_in_timezone(timezone)
    # ISO week starts on Monday (day 1)
    day_of_week = Date.day_of_week(today)
    start_of_week = Date.add(today, -(day_of_week - 1))
    end_of_week = Date.add(start_of_week, 6)

    {start_of_week, end_of_week}
  end

  defp goal_horizon_to_date_range(:monthly, timezone) do
    today = today_in_timezone(timezone)
    start_of_month = %{today | day: 1}
    end_of_month = Date.end_of_month(today)

    {start_of_month, end_of_month}
  end

  defp goal_horizon_to_date_range(:yearly, timezone) do
    today = today_in_timezone(timezone)
    start_of_year = %{today | month: 1, day: 1}
    end_of_year = %{today | month: 12, day: 31}

    {start_of_year, end_of_year}
  end

  defp today_in_timezone(timezone) do
    case DateTime.shift_zone(DateTime.utc_now(:second), timezone) do
      {:ok, shifted} -> DateTime.to_date(shifted)
      _ -> DateTime.utc_now(:second) |> DateTime.to_date()
    end
  end

  defp delete_log_for_date(%Habit{} = habit, %Date{} = local_date) do
    case Repo.get_by(HabitLog, habit_id: habit.id, local_date: local_date) do
      nil -> {:ok, :noop}
      log -> Repo.delete(log)
    end
  end

  defp normalize_local_date(_habit, %Date{} = date), do: {:ok, date}

  defp normalize_local_date(habit, %DateTime{} = dt) do
    timezone = habit_timezone(habit)

    case DateTime.shift_zone(dt, timezone) do
      {:ok, shifted} -> {:ok, DateTime.to_date(shifted)}
      _ -> {:ok, DateTime.to_date(dt)}
    end
  end

  defp normalize_local_date(habit, %NaiveDateTime{} = dt) do
    timezone = habit_timezone(habit)

    case DateTime.from_naive(dt, timezone) do
      {:ok, zoned} -> {:ok, DateTime.to_date(zoned)}
      _ -> {:ok, NaiveDateTime.to_date(dt)}
    end
  end

  defp normalize_local_date(_habit, date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed} -> {:ok, parsed}
      _ -> {:error, :invalid_date}
    end
  end

  defp normalize_local_date(habit, nil) do
    timezone = habit_timezone(habit)

    date =
      case DateTime.shift_zone(DateTime.utc_now(:second), timezone) do
        {:ok, shifted} -> DateTime.to_date(shifted)
        _ -> DateTime.utc_now(:second) |> DateTime.to_date()
      end

    {:ok, date}
  end

  defp normalize_local_date(_habit, _), do: {:error, :invalid_date}

  defp habit_timezone(%Habit{user: %User{timezone: timezone}}), do: timezone

  defp habit_timezone(%Habit{user_id: user_id}) do
    Accounts.get_user!(user_id).timezone
  end

  defp fetch_attr(attrs, key) do
    cond do
      Map.has_key?(attrs, key) -> {true, Map.get(attrs, key)}
      Map.has_key?(attrs, Atom.to_string(key)) -> {true, Map.get(attrs, Atom.to_string(key))}
      true -> {false, nil}
    end
  end

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) and value != "" do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_int(_), do: nil

  defp normalize_notes(nil), do: nil

  defp normalize_notes(notes) when is_binary(notes) do
    notes = String.trim(notes)
    if notes == "", do: nil, else: notes
  end

  defp normalize_notes(notes), do: notes

  defp normalize_status(status) when is_atom(status), do: status

  defp normalize_status(status) when is_binary(status) do
    case String.downcase(status) do
      "planned" -> :planned
      "complete" -> :complete
      "not_complete" -> :not_complete
      _ -> nil
    end
  end

  defp normalize_status(_), do: nil

  defp maybe_put(attrs, _key, false, _value), do: attrs
  defp maybe_put(attrs, key, true, value), do: Map.put(attrs, key, value)

  defp maybe_put_default_status(attrs, true, _log, _notes, _numeric_value, _duration_minutes),
    do: attrs

  defp maybe_put_default_status(attrs, false, nil, notes, numeric_value, duration_minutes)
       when not is_nil(notes) or not is_nil(numeric_value) or not is_nil(duration_minutes) do
    Map.put(attrs, :status, :planned)
  end

  defp maybe_put_default_status(
         attrs,
         _status_present?,
         _log,
         _notes,
         _numeric_value,
         _duration_minutes
       ),
       do: attrs

  defp has_string_keys?(attrs) do
    Enum.any?(Map.keys(attrs), &is_binary/1)
  end
end
