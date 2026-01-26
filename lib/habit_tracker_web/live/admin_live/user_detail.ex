defmodule HabitTrackerWeb.AdminLive.UserDetail do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Admin
  import HabitTrackerWeb.AdminComponents

  @impl true
  def mount(%{"id" => user_id}, _session, socket) do
    case Admin.get_user_summary(user_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> push_navigate(to: ~p"/admin/users")}

      summary ->
        {:ok,
         socket
         |> assign(:current_scope, %{})
         |> assign(:user_summary, summary)
         |> assign(:user, summary.user)
         |> assign(:show_delete_modal, false)
         |> assign(:page_title, "User Details")}
    end
  end

  @impl true
  def handle_event("toggle_active", _params, socket) do
    user = socket.assigns.user
    admin = socket.assigns.current_admin

    result =
      if user.deleted_at do
        Admin.reactivate_user(admin, user)
      else
        Admin.deactivate_user(admin, user)
      end

    case result do
      {:ok, updated_user} ->
        summary = Admin.get_user_summary(updated_user.id)

        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> assign(:user_summary, summary)
         |> put_flash(
           :info,
           if(updated_user.deleted_at, do: "User deactivated", else: "User reactivated")
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update user status")}
    end
  end

  @impl true
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl true
  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    user = socket.assigns.user
    admin = socket.assigns.current_admin

    case Admin.admin_delete_user(admin, user) do
      {:ok, _deleted_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User account deleted")
         |> push_navigate(to: ~p"/admin/users")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:show_delete_modal, false)
         |> put_flash(:error, "Failed to delete user")}
    end
  end

  @impl true
  def handle_event("force_password_reset", _params, socket) do
    user = socket.assigns.user
    admin = socket.assigns.current_admin

    case Admin.force_password_reset(admin, user) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset initiated for user")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to initiate password reset")}
    end
  end

  @impl true
  def handle_event("view_as_user", _params, socket) do
    user = socket.assigns.user
    admin = socket.assigns.current_admin

    # Log the impersonation start
    Admin.log_impersonation_start(admin, user.id)

    # Redirect to a controller action that will set the session
    {:noreply,
     socket
     |> put_flash(:info, "Viewing as #{user.email} (read-only mode)")
     |> redirect(to: ~p"/admin/impersonate/#{user.id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.admin_nav current_path={~p"/admin/users"} />
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Back button --%>
        <div class="mb-6">
          <.link
            navigate={~p"/admin/users"}
            class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" />
            Back to users
          </.link>
        </div>

        <%!-- User Header --%>
        <div class="mb-8">
          <div class="flex items-center gap-4">
            <div class="h-16 w-16 rounded-full bg-gradient-to-br from-blue-100 to-cyan-100 dark:from-blue-900/20 dark:to-cyan-900/20 flex items-center justify-center">
              <.icon name="hero-user" class="h-8 w-8 text-blue-600 dark:text-blue-400" />
            </div>
            <div class="flex-1">
              <h1 class="text-3xl font-bold text-gray-900">
                <%= @user.email %>
              </h1>
              <p class="mt-1 text-sm text-gray-500">
                User ID: <%= @user.id %>
              </p>
            </div>
            <%= if @user.deleted_at do %>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800">
                Deactivated
              </span>
            <% else %>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                Active
              </span>
            <% end %>
          </div>
        </div>

        <%!-- User Summary --%>
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4 mb-8">
          <div class="bg-white overflow-hidden shadow rounded-lg border border-gray-200">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <.icon name="hero-calendar" class="h-6 w-6 text-gray-400" />
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Joined
                    </dt>
                    <dd class="text-lg font-semibold text-gray-900">
                      <%= format_date(@user.inserted_at) %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg border border-gray-200">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <.icon name="hero-clipboard-document-list" class="h-6 w-6 text-gray-400" />
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Habits
                    </dt>
                    <dd class="text-lg font-semibold text-gray-900">
                      <%= @user_summary.habit_count %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg border border-gray-200">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <.icon name="hero-check-circle" class="h-6 w-6 text-gray-400" />
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Logs
                    </dt>
                    <dd class="text-lg font-semibold text-gray-900">
                      <%= @user_summary.log_count %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg border border-gray-200">
            <div class="p-5">
              <div class="flex items-center">
                <div class="flex-shrink-0">
                  <.icon name="hero-globe-alt" class="h-6 w-6 text-gray-400" />
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Timezone
                    </dt>
                    <dd class="text-sm font-semibold text-gray-900">
                      <%= @user.timezone %>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Actions --%>
        <div class="bg-white shadow rounded-lg border border-gray-200">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">
              Admin Actions
            </h3>

            <div class="space-y-4">
              <%!-- View as User --%>
              <div class="flex items-center justify-between">
                <div>
                  <h4 class="text-sm font-medium text-gray-900">
                    View as User
                  </h4>
                  <p class="text-sm text-gray-500">
                    View the user's dashboard in read-only mode
                  </p>
                </div>
                <button
                  phx-click="view_as_user"
                  class="inline-flex items-center gap-2 px-4 py-2 border-2 border-gray-300 dark:border-gray-600 text-sm font-semibold rounded-xl text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:border-gray-400 dark:hover:border-gray-500 transition-all"
                >
                  <.icon name="hero-eye" class="w-4 h-4" />
                  View Dashboard
                </button>
              </div>

              <%!-- Toggle Active Status --%>
              <div class="flex items-center justify-between border-t border-gray-200 pt-4">
                <div>
                  <h4 class="text-sm font-medium text-gray-900">
                    <%= if @user.deleted_at, do: "Reactivate Account", else: "Deactivate Account" %>
                  </h4>
                  <p class="text-sm text-gray-500">
                    <%= if @user.deleted_at do %>
                      Restore access to this user account
                    <% else %>
                      Temporarily disable access to this account
                    <% end %>
                  </p>
                </div>
                <button
                  phx-click="toggle_active"
                  class={[
                    "inline-flex items-center gap-2 px-4 py-2 border-2 text-sm font-semibold rounded-xl transition-all",
                    if(@user.deleted_at,
                      do:
                        "border-green-300 dark:border-green-700 text-green-700 dark:text-green-400 bg-white dark:bg-gray-800 hover:bg-green-50 dark:hover:bg-green-900/20",
                      else:
                        "border-yellow-300 dark:border-yellow-700 text-yellow-700 dark:text-yellow-400 bg-white dark:bg-gray-800 hover:bg-yellow-50 dark:hover:bg-yellow-900/20"
                    )
                  ]}
                >
                  <%= if @user.deleted_at do %>
                    <.icon name="hero-check-circle" class="w-4 h-4" />
                    Reactivate
                  <% else %>
                    <.icon name="hero-no-symbol" class="w-4 h-4" />
                    Deactivate
                  <% end %>
                </button>
              </div>

              <%!-- Force Password Reset --%>
              <div class="flex items-center justify-between border-t border-gray-200 pt-4">
                <div>
                  <h4 class="text-sm font-medium text-gray-900">
                    Force Password Reset
                  </h4>
                  <p class="text-sm text-gray-500">
                    Invalidate all tokens and send password reset email
                  </p>
                </div>
                <button
                  phx-click="force_password_reset"
                  class="inline-flex items-center gap-2 px-4 py-2 border-2 border-gray-300 dark:border-gray-600 text-sm font-semibold rounded-xl text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:border-gray-400 dark:hover:border-gray-500 transition-all"
                >
                  <.icon name="hero-key" class="w-4 h-4" />
                  Reset Password
                </button>
              </div>

              <%!-- Delete Account --%>
              <div class="flex items-center justify-between border-t border-gray-200 pt-4">
                <div>
                  <h4 class="text-sm font-medium text-red-900">
                    Delete Account
                  </h4>
                  <p class="text-sm text-red-600">
                    Permanently delete this user account and all associated data
                  </p>
                </div>
                <button
                  phx-click="show_delete_modal"
                  class="inline-flex items-center px-4 py-2 border border-red-300 text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                >
                  <.icon name="hero-trash" class="w-4 h-4 mr-2" />
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Delete Confirmation Modal --%>
      <%= if @show_delete_modal do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex items-center justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
            <div class="fixed inset-0 transition-opacity bg-gray-500 bg-opacity-75" phx-click="hide_delete_modal" />

            <div
              class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full"
              phx-click-away="hide_delete_modal"
            >
              <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-red-100 sm:mx-0 sm:h-10 sm:w-10">
                    <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-600" />
                  </div>
                  <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                    <h3 class="text-lg leading-6 font-medium text-gray-900">
                      Delete User Account
                    </h3>
                    <div class="mt-2">
                      <p class="text-sm text-gray-500">
                        Are you sure you want to delete this user account? This action will soft-delete the account immediately. All data will be permanently removed after 30 days. This action cannot be undone.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <button
                  type="button"
                  phx-click="confirm_delete"
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Delete
                </button>
                <button
                  type="button"
                  id="cancel-delete"
                  phx-click="hide_delete_modal"
                  class="mt-3 w-full inline-flex justify-center rounded-xl border-2 border-gray-300 dark:border-gray-600 shadow-sm px-4 py-2 bg-white dark:bg-gray-800 text-base font-semibold text-gray-700 dark:text-gray-300 hover:border-gray-400 dark:hover:border-gray-500 transition-all sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
