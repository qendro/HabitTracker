defmodule HabitTrackerWeb.Layouts do
  use HabitTrackerWeb, :html
  embed_templates "layouts/*"
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div aria-live="polite">
      <p :if={Phoenix.Flash.get(@flash, :info)} role="status">{Phoenix.Flash.get(@flash, :info)}</p>
      <p :if={Phoenix.Flash.get(@flash, :error)} role="alert">{Phoenix.Flash.get(@flash, :error)}</p>
    </div>
    """
  end
end
