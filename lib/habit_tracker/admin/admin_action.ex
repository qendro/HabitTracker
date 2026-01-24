defmodule HabitTracker.Admin.AdminAction do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_actions ~w(
    deactivate_user
    reactivate_user
    delete_user_requested
    force_password_reset
    view_as_started
    view_as_ended
  )

  schema "admin_actions" do
    field :action, :string
    field :success, :boolean, default: true
    field :metadata, :map

    belongs_to :admin, HabitTracker.Admin.Admin
    belongs_to :target_user, HabitTracker.Accounts.User

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(admin_action, attrs) do
    admin_action
    |> cast(attrs, [:admin_id, :action, :target_user_id, :success, :metadata])
    |> validate_required([:admin_id, :action, :success])
    |> validate_inclusion(:action, @valid_actions)
    |> scrub_sensitive_metadata()
  end

  defp scrub_sensitive_metadata(changeset) do
    case get_change(changeset, :metadata) do
      nil ->
        changeset

      metadata when is_map(metadata) ->
        scrubbed =
          metadata
          |> Map.drop(["password", "token", "hashed_password"])
          |> Enum.map(fn {k, v} ->
            cond do
              String.contains?(String.downcase(k), "password") -> {k, "[REDACTED]"}
              String.contains?(String.downcase(k), "token") -> {k, "[REDACTED]"}
              true -> {k, v}
            end
          end)
          |> Map.new()

        put_change(changeset, :metadata, scrubbed)

      _ ->
        changeset
    end
  end

  @doc """
  Returns the list of valid action types.
  """
  def valid_actions, do: @valid_actions
end
