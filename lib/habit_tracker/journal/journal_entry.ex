defmodule HabitTracker.Journal.JournalEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @max_words 5000

  schema "journal_entries" do
    field :local_date, :date
    field :content, :string
    field :word_count, :integer, default: 0

    belongs_to :user, HabitTracker.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @fields [:local_date, :content, :word_count]
  @required_fields [:local_date, :content]

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_content_presence()
    |> update_word_count()
    |> validate_number(:word_count, greater_than_or_equal_to: 0)
    |> validate_word_limit()
    |> unique_constraint([:user_id, :local_date])
  end

  def max_words, do: @max_words

  def word_count(nil), do: 0

  def word_count(content) when is_binary(content) do
    content
    |> String.trim()
    |> case do
      "" -> 0
      trimmed -> String.split(trimmed, ~r/\s+/u, trim: true) |> length()
    end
  end

  defp update_word_count(changeset) do
    content = get_field(changeset, :content)
    count = word_count(content)
    put_change(changeset, :word_count, count)
  end

  defp validate_content_presence(changeset) do
    validate_change(changeset, :content, fn :content, content ->
      if is_binary(content) and String.trim(content) == "" do
        [content: "can't be blank"]
      else
        []
      end
    end)
  end

  defp validate_word_limit(changeset) do
    count = get_field(changeset, :word_count) || 0

    if count > @max_words do
      add_error(changeset, :content, "must be #{@max_words} words or less")
    else
      changeset
    end
  end
end
