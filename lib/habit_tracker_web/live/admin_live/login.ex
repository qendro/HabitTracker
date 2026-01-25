defmodule HabitTrackerWeb.AdminLive.Login do
  use HabitTrackerWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            Admin log in
            <:subtitle>
              Use your admin credentials to access the admin area.
            </:subtitle>
          </.header>
        </div>

        <.form
          for={@form}
          id="admin_login_form"
          action={~p"/admin/log-in"}
          phx-submit="submit"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            field={@form[:email]}
            id="admin_login_email"
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            required
          />
          <.button class="w-full" phx-disable-with="Signing in...">
            Log in
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "admin")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
