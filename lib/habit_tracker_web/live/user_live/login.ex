defmodule HabitTrackerWeb.UserLive.Login do
  use HabitTrackerWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1>Health Journal</h1>
    <p>Your private health observations.</p>
    <Layouts.flash_group flash={@flash} />
    <.form for={%{}} action={~p"/users/log-in"} id="login-form">
      <label>Email<input name="user[email]" type="email" autocomplete="username" required /></label>
      <label>
        Password<input name="user[password]" type="password" autocomplete="current-password" required />
      </label>
      <input type="hidden" name="user[remember_me]" value="true" />
      <button>Sign in</button>
    </.form>
    <p>
      Account setup and password recovery use the private owner command. There is no public signup or email recovery.
    </p>
    """
  end
end
