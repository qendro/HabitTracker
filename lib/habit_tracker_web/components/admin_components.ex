defmodule HabitTrackerWeb.AdminComponents do
  @moduledoc """
  Provides UI components for admin pages.
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
    <nav class="bg-white shadow-sm border-b border-gray-200 mb-6">
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex">
            <div class="flex-shrink-0 flex items-center">
              <span class="text-xl font-bold text-indigo-600">Admin Panel</span>
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
              class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4 mr-2" />
              Log out
            </.link>
          </div>
        </div>
      </div>
      
      <%!-- Mobile menu --%>
      <div class="sm:hidden border-t border-gray-200">
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
        "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium",
        if(@active,
          do: "border-indigo-500 text-gray-900",
          else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
        )
      ]}
    >
      <.icon name={@icon} class="h-4 w-4 mr-2" />
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
        "flex items-center pl-3 pr-4 py-2 border-l-4 text-base font-medium",
        if(@active,
          do: "bg-indigo-50 border-indigo-500 text-indigo-700",
          else: "border-transparent text-gray-600 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-800"
        )
      ]}
    >
      <.icon name={@icon} class="h-5 w-5 mr-3" />
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end
end
