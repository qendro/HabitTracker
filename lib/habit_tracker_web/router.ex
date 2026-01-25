defmodule HabitTrackerWeb.Router do
  use HabitTrackerWeb, :router

  import HabitTrackerWeb.UserAuth
  import HabitTrackerWeb.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HabitTrackerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :put_current_path
  end

  defp put_current_path(conn, _opts) do
    Plug.Conn.assign(conn, :current_path, conn.request_path)
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check endpoint (no authentication required)
  scope "/", HabitTrackerWeb do
    pipe_through :api

    get "/health", HealthController, :check
  end

  pipeline :admin_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HabitTrackerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_admin
  end

  scope "/", HabitTrackerWeb do
    pipe_through :browser

    # Redirect root to today's habits for authenticated users, or login for guests
    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", HabitTrackerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:habit_tracker, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HabitTrackerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", HabitTrackerWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{HabitTrackerWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      
      # App settings
      live "/app/settings", SettingsLive, :index
      
      # Today dashboard routes
      live "/app/today", TodayLive, :index
      live "/app/day/:date", TodayLive, :show
      
      # Habit management routes
      live "/app/habits", HabitsLive, :index
      live "/app/habits/new", HabitFormLive, :new
      live "/app/habits/:id/edit", HabitFormLive, :edit
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", HabitTrackerWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{HabitTrackerWeb.UserAuth, :mount_current_scope}] do
      live "/welcome", WelcomeLive, :index
      live "/users/log-in", UserLive.Login, :new
      live "/users/confirm/:token", UserLive.Confirmation, :new
      live "/users/reset-password", UserLive.ResetPasswordRequest, :new
      live "/users/reset-password/:token", UserLive.ResetPassword, :edit
    end

    # Use controller for registration (more reliable than LiveView)
    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## Admin routes

  scope "/admin", HabitTrackerWeb do
    pipe_through [:admin_browser, :redirect_if_admin_is_authenticated]

    live_session :admin_current,
      on_mount: [{HabitTrackerWeb.AdminAuth, :mount_current_admin}] do
      live "/login", AdminLive.Login, :new
    end

    post "/log-in", AdminSessionController, :create
  end

  scope "/admin", HabitTrackerWeb do
    pipe_through [:admin_browser, :require_authenticated_admin]

    live_session :require_authenticated_admin,
      on_mount: [{HabitTrackerWeb.AdminAuth, :require_authenticated_admin}] do
      live "/", AdminLive.Home, :index
      live "/users", AdminLive.Users, :index
      live "/users/:id", AdminLive.UserDetail, :show
      live "/activity", AdminLive.Activity, :index
    end

    get "/impersonate/:user_id", AdminSessionController, :impersonate
    delete "/log-out", AdminSessionController, :delete
    post "/stop-impersonation", AdminSessionController, :stop_impersonation
  end
end
