defmodule HabitTracker.ReleaseTest do
  use HabitTracker.DataCase, async: true
  alias HabitTracker.{Release, Accounts}

  test "provisioning never resets existing owner and explicit reset revokes sessions" do
    assert {:ok, user} = Release.provision_owner("owner@example.test", "synthetic test password")
    assert user.confirmed_at
    token = Accounts.generate_user_session_token(user)
    assert {:error, :exists} = Release.provision_owner(user.email, "different password")
    assert Accounts.get_user_by_email_and_password(user.email, "synthetic test password")

    assert {:error, :owner_already_provisioned} =
             Release.provision_owner("other@example.test", "another password")

    assert {:ok, _} = Release.provision_owner(user.email, "new synthetic password", true)
    refute Accounts.get_user_by_session_token(token)
    assert Accounts.get_user_by_email_and_password(user.email, "new synthetic password")
  end
end
