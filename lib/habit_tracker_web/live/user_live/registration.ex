defmodule HabitTrackerWeb.UserLive.Registration do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Accounts
  alias HabitTrackerWeb.RateLimiter
  alias HabitTracker.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Register for an account
            <:subtitle>
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Log in
              </.link>
              to your account now.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
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
            autocomplete="new-password"
            required
          />
          <.input
            field={@form[:timezone]}
            type="hidden"
            id="registration-timezone"
            phx-hook="TimezoneDetect"
          />

          <.button phx-disable-with="Creating account..." class="w-full">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: HabitTrackerWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset =
      Accounts.change_user_registration(%User{}, %{},
        validate_unique: false,
        hash_password: false
      )

    socket =
      socket
      |> assign_form(changeset)
      |> assign(:client_ip, get_client_ip(socket))

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case RateLimiter.check_registration(socket.assigns.client_ip) do
      :deny ->
        {:noreply,
         socket
         |> put_flash(:error, "Too many registration attempts. Please try again later.")
         |> push_navigate(to: ~p"/users/register")}

      :allow ->
        case Accounts.register_user(user_params) do
          {:ok, user} ->
            {:ok, _} =
              Accounts.deliver_user_confirmation_instructions(
                user,
                &url(~p"/users/confirm/#{&1}")
              )

            {:noreply,
             socket
             |> put_flash(
               :info,
               "Please check #{user.email} for a confirmation link to activate your account."
             )
             |> push_navigate(to: ~p"/users/log-in")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_form(socket, changeset)}
        end
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_registration(%User{}, user_params,
        validate_unique: false,
        hash_password: false
      )

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end

  defp get_client_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} -> address |> :inet.ntoa() |> to_string()
      _ -> nil
    end
  end
end
