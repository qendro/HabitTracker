defmodule HabitTracker.HealthJournal.Entry do
  use Ecto.Schema
  import Ecto.Changeset
  alias HabitTracker.HealthJournal.{Time, Stool, CheckIn, Note}

  schema "health_entries" do
    belongs_to :user, HabitTracker.Accounts.User
    field :kind, :string
    field :occurred_at, :utc_datetime_usec
    field :event_timezone, :string
    field :notes, :string, redact: true
    field :details, :map, default: %{}, redact: true
    field :client_entry_id, Ecto.UUID
    field :source, :string, default: "manual"
    field :lock_version, :integer, default: 1
    has_many :attachments, HabitTracker.HealthJournal.Attachment
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:kind, :occurred_at, :event_timezone, :notes, :client_entry_id, :details])
    |> validate_required([:kind, :occurred_at, :event_timezone, :client_entry_id])
    |> validate_inclusion(:kind, ~w(stool check_in note))
    |> validate_length(:notes, max: 10000)
    |> validate_change(:event_timezone, fn :event_timezone, zone ->
      if Time.valid_zone?(zone), do: [], else: [event_timezone: "is invalid"]
    end)
    |> validate_change(:occurred_at, fn :occurred_at, dt ->
      if DateTime.diff(dt, DateTime.utc_now()) <= 120,
        do: [],
        else: [occurred_at: "cannot be in the future (two minutes clock skew allowed)"]
    end)
    |> validate_details()
    |> unique_constraint([:user_id, :client_entry_id])
  end

  defp validate_details(cs) do
    module =
      case get_field(cs, :kind) do
        "stool" -> Stool
        "check_in" -> CheckIn
        "note" -> Note
        _ -> nil
      end

    case module do
      nil ->
        cs

      module ->
        attrs = get_field(cs, :details) || %{}
        keys = apply(module, :__schema__, [:fields]) |> Enum.map(&Atom.to_string/1)
        detail = apply(module, :changeset, [struct(module), attrs])

        cond do
          Enum.any?(Map.keys(attrs), &(to_string(&1) not in keys)) ->
            add_error(cs, :details, "contains unknown or mismatched fields")

          not detail.valid? ->
            add_error(cs, :details, "contains invalid ratings or category")

          true ->
            values =
              apply_changes(detail)
              |> Map.from_struct()
              |> Map.drop([:__meta__])
              |> Map.new(fn {k, v} -> {to_string(k), v} end)

            cs = put_change(cs, :details, values)
            blank = is_nil(get_field(cs, :notes)) or String.trim(get_field(cs, :notes)) == ""

            if blank and
                 (module == Note or
                    (module == CheckIn and Enum.all?(Map.values(values), &is_nil/1))),
               do: add_error(cs, :notes, "record a note or at least one rating"),
               else: cs
        end
    end
  end
end
