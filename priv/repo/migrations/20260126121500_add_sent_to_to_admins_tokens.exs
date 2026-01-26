defmodule HabitTracker.Repo.Migrations.AddSentToToAdminsTokens do
  use Ecto.Migration

  def change do
    alter table(:admins_tokens) do
      add :sent_to, :string
    end
  end
end
