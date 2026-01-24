defmodule HabitTrackerWeb.AdminLive.Activity do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Admin
  alias HabitTracker.Admin.AdminAction

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:page_title, "Admin Activity Log")
     |> assign(:filter_action, "all")
     |> assign(:filter_user_id, nil)
     |> assign(:page, 1)
     |> assign(:per_page, 50)
     |> load_actions()}
  end

  @impl true
  def handle_event("filter_by_action", %{"action" => action}, socket) do
    {:noreply,
     socket
     |> assign(:filter_action, action)
     |> assign(:page, 1)
     |> load_actions()}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filter_action, "all")
     |> assign(:filter_user_id, nil)
     |> assign(:page, 1)
     |> load_actions()}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    {:noreply,
     socket
     |> update(:page, &(&1 + 1))
     |> load_actions()}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    {:noreply,
     socket
     |> update(:page, &max(&1 - 1, 1))
     |> load_actions()}
  end

  defp load_actions(socket) do
    filters = build_filters(socket)
    all_actions = Admin.list_admin_actions(filters)

    page = socket.assigns.page
    per_page = socket.assigns.per_page
    start_index = (page - 1) * per_page
    end_index = start_index + per_page - 1

    actions = Enum.slice(all_actions, start_index..end_index)
    total_count = length(all_actions)
    has_more = end_index < total_count - 1

    socket
    |> assign(:actions, actions)
    |> assign(:total_count, total_count)
    |> assign(:has_more, has_more)
    |> assign(:has_prev, page > 1)
  end

  defp build_filters(socket) do
    filters = %{}

    filters =
      if socket.assigns.filter_action != "all" do
        Map.put(filters, :action, socket.assigns.filter_action)
      else
        filters
      end

    filters =
      if socket.assigns.filter_user_id do
        Map.put(filters, :target_user_id, socket.assigns.filter_user_id)
      else
        filters
      end

    filters
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">
            Admin Activity Log
          </h1>
          <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
            View all admin actions and security events
          </p>
        </div>

        <%!-- Filters --%>
        <div class="mb-6 bg-white dark:bg-gray-800 shadow rounded-lg border border-gray-200 dark:border-gray-700 p-4">
          <div class="flex items-center gap-4">
            <div class="flex-1">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Filter by Action
              </label>
              <select
                phx-change="filter_by_action"
                name="action"
                class="block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              >
                <option value="all" selected={@filter_action == "all"}>All Actions</option>
                <option
                  :for={action <- AdminAction.valid_actions()}
                  value={action}
                  selected={@filter_action == action}
                >
                  <%= format_action_name(action) %>
                </option>
              </select>
            </div>

            <%= if @filter_action != "all" do %>
              <div class="pt-6">
                <button
                  phx-click="clear_filters"
                  class="inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 text-sm font-medium rounded-md text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  Clear Filters
                </button>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Results Summary --%>
        <div class="mb-4 text-sm text-gray-600 dark:text-gray-400">
          Showing <%= length(@actions) %> of <%= @total_count %> actions
        </div>

        <%!-- Actions List --%>
        <%= if @actions == [] do %>
          <div class="text-center py-12 bg-white dark:bg-gray-800 shadow rounded-lg border border-gray-200 dark:border-gray-700">
            <.icon name="hero-clipboard-document-list" class="mx-auto h-12 w-12 text-gray-400" />
            <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-gray-100">
              No activity found
            </h3>
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
              No admin actions match the current filters
            </p>
          </div>
        <% else %>
          <div class="bg-white dark:bg-gray-800 shadow overflow-hidden sm:rounded-md border border-gray-200 dark:border-gray-700">
            <ul class="divide-y divide-gray-200 dark:divide-gray-700">
              <li :for={action <- @actions} class="px-4 py-4 sm:px-6">
                <div class="flex items-start justify-between">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-3 mb-2">
                      <span class={[
                        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                        action_badge_class(action.action)
                      ]}>
                        <%= format_action_name(action.action) %>
                      </span>

                      <%= if action.success do %>
                        <span class="inline-flex items-center text-xs text-green-600 dark:text-green-400">
                          <.icon name="hero-check-circle" class="w-4 h-4 mr-1" />
                          Success
                        </span>
                      <% else %>
                        <span class="inline-flex items-center text-xs text-red-600 dark:text-red-400">
                          <.icon name="hero-x-circle" class="w-4 h-4 mr-1" />
                          Failed
                        </span>
                      <% end %>
                    </div>

                    <div class="text-sm text-gray-900 dark:text-gray-100">
                      <span class="font-medium"><%= action.admin.email %></span>
                      <%= action_description(action) %>
                    </div>

                    <div class="mt-2 flex items-center gap-4 text-xs text-gray-500 dark:text-gray-400">
                      <span>
                        <.icon name="hero-clock" class="w-3 h-3 inline mr-1" />
                        <%= format_datetime(action.inserted_at) %>
                      </span>
                      <%= if action.target_user do %>
                        <span>
                          <.icon name="hero-user" class="w-3 h-3 inline mr-1" />
                          <%= action.target_user.email %>
                        </span>
                      <% end %>
                    </div>

                    <%= if !action.success && action.metadata do %>
                      <div class="mt-2 p-2 bg-red-50 dark:bg-red-900/20 rounded text-xs">
                        <span class="font-medium text-red-800 dark:text-red-300">Error:</span>
                        <pre class="mt-1 text-red-700 dark:text-red-400 whitespace-pre-wrap"><%= inspect(
                            action.metadata,
                            pretty: true
                          ) %></pre>
                      </div>
                    <% end %>
                  </div>
                </div>
              </li>
            </ul>
          </div>

          <%!-- Pagination --%>
          <div class="mt-4 flex items-center justify-between">
            <button
              phx-click="prev_page"
              disabled={!@has_prev}
              class={[
                "inline-flex items-center px-4 py-2 border text-sm font-medium rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
                if(@has_prev,
                  do:
                    "border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600",
                  else: "border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-600 bg-gray-100 dark:bg-gray-800 cursor-not-allowed"
                )
              ]}
            >
              <.icon name="hero-chevron-left" class="w-4 h-4 mr-2" />
              Previous
            </button>

            <span class="text-sm text-gray-600 dark:text-gray-400">
              Page <%= @page %>
            </span>

            <button
              phx-click="next_page"
              disabled={!@has_more}
              class={[
                "inline-flex items-center px-4 py-2 border text-sm font-medium rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
                if(@has_more,
                  do:
                    "border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600",
                  else: "border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-600 bg-gray-100 dark:bg-gray-800 cursor-not-allowed"
                )
              ]}
            >
              Next
              <.icon name="hero-chevron-right" class="w-4 h-4 ml-2" />
            </button>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_action_name(action) do
    action
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp action_badge_class(action) do
    case action do
      "view_as_started" -> "bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300"
      "view_as_ended" -> "bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300"
      "deactivate_user" -> "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300"
      "reactivate_user" -> "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300"
      "delete_user_requested" -> "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300"
      "force_password_reset" -> "bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-300"
      _ -> "bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-300"
    end
  end

  defp action_description(action) do
    case action.action do
      "view_as_started" -> " started viewing as user"
      "view_as_ended" -> " stopped viewing as user"
      "deactivate_user" -> " deactivated user account"
      "reactivate_user" -> " reactivated user account"
      "delete_user_requested" -> " deleted user account"
      "force_password_reset" -> " forced password reset for user"
      _ -> " performed action"
    end
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %H:%M:%S UTC")
  end
end
