defmodule HabitTracker.AdminFixtures do
  @moduledoc """
  This module defines test helpers for creating admin accounts.
  """

  alias HabitTracker.Admin

  def unique_admin_email, do: "admin#{System.unique_integer()}@example.com"
  def valid_admin_password, do: "hello admin!"

  def admin_fixture(attrs \\ %{}) do
    {:ok, admin} =
      attrs
      |> Enum.into(%{
        email: unique_admin_email(),
        password: valid_admin_password()
      })
      |> Admin.register_admin()

    admin
  end
end
