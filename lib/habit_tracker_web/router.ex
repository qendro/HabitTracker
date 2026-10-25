defmodule HabitTrackerWeb.Router do
  use HabitTrackerWeb, :router
  import HabitTrackerWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HabitTrackerWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "cache-control" => "private, no-store",
      "referrer-policy" => "same-origin"
    }

    plug :fetch_current_scope_for_user
  end

  scope "/", HabitTrackerWeb do
    get "/health", HealthController, :check
  end

  scope "/", HabitTrackerWeb do
    pipe_through :browser
    get "/", PageController, :home

    live_session :login, on_mount: [{HabitTrackerWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  scope "/", HabitTrackerWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :journal, on_mount: [{HabitTrackerWeb.UserAuth, :require_authenticated}] do
      live "/app/today", TimelineLive, :today
      live "/app/history", TimelineLive, :history
      live "/app/entries/new/:kind", EntryFormLive, :new
      live "/app/entries/:id/edit", EntryFormLive, :edit
      live "/app/entries/:id", EntryDetailLive, :show
      live "/app/settings", SettingsLive, :index
    end

    post "/users/update-password", UserSessionController, :update_password
    get "/attachments/:id/:variant", DownloadController, :photo
    get "/export", DownloadController, :export
  end
end
