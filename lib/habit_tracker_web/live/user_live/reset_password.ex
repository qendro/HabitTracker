defmodule HabitTrackerWeb.UserLive.ResetPassword do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts
  alias HabitTracker.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Set a new password
            <:subtitle>Create a new password for your account.</:subtitle>
          </.header>
        </div>

        <.form
          for={@form}
          id="reset_password_form"
          phx-change="validate"
          phx-submit="reset_password"
        >
          <.input
            field={@form[:password]}
            type="password"
            label="New password"
            autocomplete="new-password"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm new password"
            autocomplete="new-password"
            required
          />

          <.button phx-disable-with="Resetting..." class="w-full">
            Reset password
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_reset_password_token(token) do
      %User{} = user ->
        changeset = Accounts.change_user_password(user, %{}, hash_password: false)

        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:token, token)
         |> assign(:form, to_form(changeset))}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Reset link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/reset-password")}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.get_user_by_reset_password_token(socket.assigns.token) do
      %User{} = user ->
        case Accounts.reset_user_password(user, user_params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Password reset successfully.")
             |> push_navigate(to: ~p"/users/log-in")}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Reset link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/reset-password")}
    end
  end
end
