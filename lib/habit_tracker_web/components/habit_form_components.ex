defmodule HabitTrackerWeb.HabitFormComponents do
  @moduledoc false
  use Phoenix.Component

  @doc """
  Renders a labeled form section with optional helper text.
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :id, :string, default: nil
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <section class="space-y-4" aria-labelledby={@id}>
      <header class="space-y-1">
        <h2 :if={@id} id={@id} class="text-lg font-semibold text-gray-900">
          <%= @title %>
        </h2>
        <h2 :if={!@id} class="text-lg font-semibold text-gray-900">
          <%= @title %>
        </h2>
        <p :if={@subtitle} class="text-sm text-gray-600">
          <%= @subtitle %>
        </p>
      </header>
      <div class="space-y-3">
        <%= render_slot(@inner_block) %>
      </div>
    </section>
    """
  end

  @doc """
  A radio-style card for selecting a single option.
  """
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :checked, :boolean, default: false
  attr :label, :string, required: true
  attr :description, :string, default: nil
  attr :rest, :global
  slot :inner_block
  slot :icon

  def choice_card(assigns) do
    ~H"""
    <label class="group block cursor-pointer">
      <input
        type="radio"
        id={@id}
        name={@name}
        value={@value}
        checked={@checked}
        class="sr-only peer"
        {@rest}
      /> 
      <div class="rounded-xl border-2 border-gray-200 bg-white p-4 transition-all group-hover:border-gray-300 peer-checked:border-blue-500 peer-checked:bg-blue-50 peer-focus-visible:ring-2 peer-focus-visible:ring-blue-400 peer-focus-visible:ring-offset-2">
        <div class="flex items-start gap-3">
          <div :if={@icon != [] or @inner_block != []} class="mt-0.5 text-xl">
            <%= if @icon != [], do: render_slot(@icon), else: render_slot(@inner_block) %>
          </div>
          <div class="space-y-1">
            <p class="text-sm font-semibold text-gray-900"><%= @label %></p>
            <p :if={@description} class="text-xs text-gray-600"><%= @description %></p>
          </div>
        </div>
      </div>
    </label>
    """
  end

end
