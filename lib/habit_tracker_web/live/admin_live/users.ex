defmodule HabitTrackerWeb.AdminLive.Users do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Admin

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:search_query, "")
     |> assign(:users, [])
     |> assign(:page_title, "User Management")}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    users = if String.trim(query) == "", do: [], else: Admin.search_users(query)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:users, users)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:users, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">
            User Management
          </h1>
          <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
            Search and manage user accounts
          </p>
        </div>

        <%!-- Search Form --%>
        <div class="mb-6">
          <.form for={%{}} phx-submit="search" phx-change="search" id="search-form">
            <div class="flex gap-2">
              <div class="flex-1">
                <input
                  type="text"
                  name="search[query]"
                  value={@search_query}
                  placeholder="Search by email or user ID..."
                  class="block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  phx-debounce="300"
                />
              </div>
              <%= if @search_query != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="inline-flex items-center px-4 py-2 border border-gray-300 dark:border-gray-600 text-sm font-medium rounded-md text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  Clear
                </button>
              <% end %>
            </div>
          </.form>
        </div>

        <%!-- Results --%>
        <%= if @search_query == "" do %>
          <div class="text-center py-12">
            <.icon name="hero-magnifying-glass" class="mx-auto h-12 w-12 text-gray-400" />
            <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-gray-100">
              Search for users
            </h3>
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
              Enter an email address or user ID to find users
            </p>
          </div>
        <% else %>
          <%= if @users == [] do %>
            <div class="text-center py-12">
              <.icon name="hero-user-group" class="mx-auto h-12 w-12 text-gray-400" />
              <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-gray-100">
                No users found
              </h3>
              <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                Try a different search query
              </p>
            </div>
          <% else %>
            <div class="bg-white dark:bg-gray-800 shadow overflow-hidden sm:rounded-md border border-gray-200 dark:border-gray-700">
              <ul class="divide-y divide-gray-200 dark:divide-gray-700">
                <li :for={user <- @users} class="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                  <.link
                    navigate={~p"/admin/users/#{user.id}"}
                    class="block px-4 py-4 sm:px-6"
                  >
                    <div class="flex items-center justify-between">
                      <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-3">
                          <div class="flex-shrink-0">
                            <div class="h-10 w-10 rounded-full bg-indigo-100 dark:bg-indigo-900 flex items-center justify-center">
                              <.icon name="hero-user" class="h-6 w-6 text-indigo-600 dark:text-indigo-400" />
                            </div>
                          </div>
                          <div class="flex-1 min-w-0">
                            <p class="text-sm font-medium text-gray-900 dark:text-gray-100 truncate">
                              <%= user.email %>
                            </p>
                            <p class="text-sm text-gray-500 dark:text-gray-400">
                              ID: <%= user.id %> • Joined <%= format_date(user.inserted_at) %>
                            </p>
                          </div>
                        </div>
                      </div>
                      <div class="ml-5 flex-shrink-0">
                        <.icon
                          name="hero-chevron-right"
                          class="h-5 w-5 text-gray-400"
                        />
                      </div>
                    </div>
                  </.link>
                </li>
              </ul>
            </div>

            <div class="mt-4 text-sm text-gray-500 dark:text-gray-400">
              Found <%= length(@users) %> user(s)
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
