defmodule HabitTracker.Tracker.Habits do
  @moduledoc false

  import Ecto.Query, warn: false

  alias HabitTracker.Accounts.User
  alias HabitTracker.Repo
  alias HabitTracker.Tracker.Habit

  def create_habit(%User{} = user, attrs) do
    attrs = ensure_position(attrs, user.id)

    %Habit{user_id: user.id}
    |> Habit.changeset(attrs)
    |> Repo.insert()
  end

  def update_habit(%Habit{} = habit, attrs) do
    habit
    |> Habit.changeset(attrs)
    |> Repo.update()
  end

  def delete_habit(%Habit{} = habit) do
    habit
    |> Habit.soft_delete_changeset()
    |> Repo.update()
  end

  def list_habits(%User{} = user) do
    Habit
    |> where([h], h.user_id == ^user.id and is_nil(h.deleted_at))
    |> order_by([h], asc: h.position, asc: h.id)
    |> Repo.all()
  end

  def get_habit!(%User{} = user, id) do
    Habit
    |> where([h], h.user_id == ^user.id and h.id == ^id and is_nil(h.deleted_at))
    |> Repo.one!()
  end

  def reorder_habits(%User{} = user, habit_ids) when is_list(habit_ids) do
    Repo.transaction(fn ->
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
        :ok -> :ok
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_position(attrs, user_id) do
    if Map.has_key?(attrs, "position") or Map.has_key?(attrs, :position) do
      attrs
    else
      if has_string_keys?(attrs) do
        Map.put(attrs, "position", next_position(user_id))
      else
        Map.put(attrs, :position, next_position(user_id))
      end
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

  defp has_string_keys?(attrs) do
    Enum.any?(Map.keys(attrs), &is_binary/1)
  end
end
