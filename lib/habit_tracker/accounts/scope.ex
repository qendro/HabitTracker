defmodule HabitTracker.Accounts.Scope do
  @moduledoc "Authenticated caller identity used by the web session."
  alias HabitTracker.Accounts.User
  defstruct user: nil
  def for_user(%User{} = user), do: %__MODULE__{user: user}
  def for_user(nil), do: nil
end
