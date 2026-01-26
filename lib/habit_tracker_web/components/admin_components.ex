defmodule HabitTrackerWeb.AdminComponents do
  @moduledoc """
  Provides UI components for admin pages using the unified design system.
  """
  use Phoenix.Component
  use HabitTrackerWeb, :verified_routes
  import HabitTrackerWeb.CoreComponents

  @doc """
  Renders an admin navigation bar.
  """
  attr :current_path, :string, required: true

  def admin_nav(assigns) do
    ~H"""
    <nav class="bg-white dark:bg-gray-800 shadow-sm border-b border-gray-200 dark:border-gray-700 mb-6">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex">
            <div class="flex-shrink-0 flex items-center">
              <span class="text-xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">Admin Panel</span>
            </div>
            <div class="hidden sm:ml-6 sm:flex sm:space-x-8">
              <.nav_link
                href={~p"/admin"}
                current={@current_path}
                icon="hero-home"
              >
                Dashboard
              </.nav_link>
              
              <.nav_link
                href={~p"/admin/users"}
                current={@current_path}
                icon="hero-users"
              >
                Users
              </.nav_link>
              
              <.nav_link
                href={~p"/admin/activity"}
                current={@current_path}
                icon="hero-clipboard-document-list"
              >
                Activity Log
              </.nav_link>
            </div>
          </div>
          
          <div class="flex items-center">
            <.link
              href={~p"/admin/log-out"}
              method="delete"
              class="inline-flex items-center gap-2 px-4 py-2 border-2 border-gray-300 dark:border-gray-600 rounded-xl text-sm font-semibold text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 hover:border-gray-400 dark:hover:border-gray-500 shadow-sm hover:shadow-md transition-all"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="h-5 w-5" />
              Log out
            </.link>
          </div>
        </div>
      </div>
      
      <%!-- Mobile menu --%>
      <div class="sm:hidden border-t border-gray-200 dark:border-gray-700">
        <div class="pt-2 pb-3 space-y-1">
          <.mobile_nav_link
            href={~p"/admin"}
            current={@current_path}
            icon="hero-home"
          >
            Dashboard
          </.mobile_nav_link>
          
          <.mobile_nav_link
            href={~p"/admin/users"}
            current={@current_path}
            icon="hero-users"
          >
            Users
          </.mobile_nav_link>
          
          <.mobile_nav_link
            href={~p"/admin/activity"}
            current={@current_path}
            icon="hero-clipboard-document-list"
          >
            Activity Log
          </.mobile_nav_link>
        </div>
      </div>
    </nav>
    """
  end

  attr :href, :string, required: true
  attr :current, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp nav_link(assigns) do
    assigns = assign(assigns, :active, assigns.href == assigns.current)

    ~H"""
    <.link
      navigate={@href}
      class={[
        "inline-flex items-center gap-2 px-1 pt-1 border-b-2 text-sm font-medium transition-colors",
        if(@active,
          do: "border-blue-600 text-blue-600 dark:text-blue-400",
          else: "border-transparent text-gray-600 dark:text-gray-400 hover:border-gray-300 dark:hover:border-gray-600 hover:text-gray-900 dark:hover:text-gray-200"
        )
      ]}
    >
      <.icon name={@icon} class="h-5 w-5" />
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  attr :href, :string, required: true
  attr :current, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp mobile_nav_link(assigns) do
    assigns = assign(assigns, :active, assigns.href == assigns.current)

    ~H"""
    <.link
      navigate={@href}
      class={[
        "flex items-center gap-3 pl-3 pr-4 py-2 border-l-4 text-base font-medium transition-colors",
        if(@active,
          do: "bg-blue-50 dark:bg-blue-900/20 border-blue-600 text-blue-600 dark:text-blue-400",
          else: "border-transparent text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 hover:border-gray-300 dark:hover:border-gray-600 hover:text-gray-900 dark:hover:text-gray-200"
        )
      ]}
    >
      <.icon name={@icon} class="h-5 w-5" />
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end
end
