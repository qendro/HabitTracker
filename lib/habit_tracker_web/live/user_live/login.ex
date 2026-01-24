defmodule HabitTrackerWeb.UserLive.Login do
  use HabitTrackerWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            <p>Log in</p>
            <:subtitle>
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                Don't have an account?
                <.link navigate={~p"/users/register"} class="font-semibold underline">
                  Sign up
                </.link>
                for an account now.
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form
          for={@form}
          id="login_form"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={@form[:email]}
            id="login_form_email"
            type="email"
            label="Email"
            autocomplete="email"
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
          <div class="flex items-center justify-between">
            <.link navigate={~p"/users/reset-password"} class="text-sm underline">
              Forgot your password?
            </.link>
          </div>
          <div class="mt-4 space-y-2">
            <.button class="w-full" name={@form[:remember_me].name} value="true">
              Log in and stay logged in
            </.button>
            <.button class="w-full">
              Log in only this time
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  defp local_mail_adapter? do
    Application.get_env(:habit_tracker, HabitTracker.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
