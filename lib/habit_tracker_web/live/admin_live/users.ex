defmodule HabitTrackerWeb.AdminLive.Users do
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Admin
  import HabitTrackerWeb.AdminComponents

  @impl true
  def mount(_params, _session, socket) do
    # Load all users by default
    users = Admin.list_all_users()
    
    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:search_query, "")
     |> assign(:users, users)
     |> assign(:showing_all, true)
     |> assign(:page_title, "User Management")}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    trimmed_query = String.trim(query)
    
    {users, showing_all} = 
      if trimmed_query == "" do
        {Admin.list_all_users(), true}
      else
        {Admin.search_users(trimmed_query), false}
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:users, users)
     |> assign(:showing_all, showing_all)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:users, Admin.list_all_users())
     |> assign(:showing_all, true)}
  end

  @impl true
  def handle_event("load_all", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:users, Admin.list_all_users())
     |> assign(:showing_all, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.admin_nav current_path={~p"/admin/users"} />
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">
            User Management
          </h1>
          <p class="mt-2 text-sm text-gray-600">
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
                  class="block w-full rounded-xl border-2 border-gray-300 dark:border-gray-600 shadow-sm focus:border-blue-500 focus:ring-4 focus:ring-blue-200 sm:text-sm text-gray-900 dark:text-white bg-white dark:bg-gray-800 placeholder-gray-400"
                  phx-debounce="300"
                />
              </div>
              <%= if @search_query != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="inline-flex items-center px-4 py-2 border-2 border-gray-300 dark:border-gray-600 text-sm font-semibold rounded-xl text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:border-gray-400 dark:hover:border-gray-500 transition-all"
                >
                  Clear
                </button>
              <% end %>
            </div>
          </.form>
        </div>

        <%!-- Results --%>
        <%= if @users == [] do %>
          <div class="text-center py-12 bg-white rounded-lg shadow border border-gray-200">
            <.icon name="hero-user-group" class="mx-auto h-12 w-12 text-gray-400" />
            <h3 class="mt-2 text-sm font-medium text-gray-900">
              No users found
            </h3>
            <p class="mt-1 text-sm text-gray-500">
              <%= if @search_query != "" do %>
                Try a different search query
              <% else %>
                No users in the system yet
              <% end %>
            </p>
          </div>
        <% else %>
          <div class="mb-4 flex items-center justify-between">
            <div class="text-sm text-gray-600">
              <%= if @showing_all do %>
                Showing all <%= length(@users) %> user(s)
              <% else %>
                Found <%= length(@users) %> user(s) matching "<%= @search_query %>"
              <% end %>
            </div>
          </div>
          
          <div class="bg-white shadow overflow-hidden sm:rounded-md border border-gray-200">
            <ul class="divide-y divide-gray-200">
              <li :for={user <- @users} class="hover:bg-gray-50">
                <.link
                  navigate={~p"/admin/users/#{user.id}"}
                  class="block px-4 py-4 sm:px-6"
                >
                  <div class="flex items-center justify-between">
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-3">
                        <div class="flex-shrink-0">
                          <div class="h-10 w-10 rounded-full bg-gradient-to-br from-blue-100 to-cyan-100 dark:from-blue-900/20 dark:to-cyan-900/20 flex items-center justify-center">
                            <.icon name="hero-user" class="h-6 w-6 text-blue-600 dark:text-blue-400" />
                          </div>
                        </div>
                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-medium text-gray-900 truncate">
                            <%= user.email %>
                          </p>
                          <p class="text-sm text-gray-500">
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
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
