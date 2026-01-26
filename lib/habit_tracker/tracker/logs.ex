defmodule HabitTracker.Tracker.Logs do
  @moduledoc false

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias HabitTracker.Accounts.User
  alias HabitTracker.Repo
  alias HabitTracker.Tracker.{Habit, HabitLog}
  alias HabitTracker.Tracker.Time

  def get_logs_for_date(%User{} = user, %Date{} = local_date) do
    HabitLog
    |> where([l], l.user_id == ^user.id and l.local_date == ^local_date)
    |> Repo.all()
  end

  def get_log(%Habit{} = habit, %Date{} = local_date) do
    Repo.get_by(HabitLog, habit_id: habit.id, local_date: local_date)
  end

  def log_habit(%Habit{} = habit, local_date, attrs) do
    with {:ok, local_date} <- Time.normalize_local_date_for_habit(habit, local_date) do
      log_habit_impl(habit, local_date, attrs)
    end
  end

  def update_habit_log(%HabitLog{} = log, attrs) do
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

  def logs_for_date(user_id, %Date{} = local_date, habit_ids) when is_list(habit_ids) do
    if habit_ids == [] do
      %{}
    else
      HabitLog
      |> where([l], l.user_id == ^user_id and l.local_date == ^local_date)
      |> where([l], l.habit_id in ^habit_ids)
      |> Repo.all()
      |> Map.new(&{&1.habit_id, &1})
    end
  end

  def completed_dates_for_habits(habit_ids, %Date{} = effective_date) when is_list(habit_ids) do
    if habit_ids == [] do
      %{}
    else
      HabitLog
      |> where([l], l.habit_id in ^habit_ids)
      |> where([l], l.status == :complete and l.local_date <= ^effective_date)
      |> select([l], {l.habit_id, l.local_date})
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {habit_id, dates} -> {habit_id, MapSet.new(dates)} end)
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

  defp delete_log_for_date(%Habit{} = habit, %Date{} = local_date) do
    case Repo.get_by(HabitLog, habit_id: habit.id, local_date: local_date) do
      nil -> {:ok, :noop}
      log -> Repo.delete(log)
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
end
