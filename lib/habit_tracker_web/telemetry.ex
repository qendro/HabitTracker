defmodule HabitTrackerWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("habit_tracker.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("habit_tracker.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("habit_tracker.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("habit_tracker.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("habit_tracker.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Application-specific metrics
      counter("habit_tracker.user.registration.count",
        description: "Total number of user registrations"
      ),
      counter("habit_tracker.user.login.count",
        description: "Total number of successful logins"
      ),
      counter("habit_tracker.user.login.failed.count",
        description: "Total number of failed login attempts"
      ),
      counter("habit_tracker.habit.created.count",
        description: "Total number of habits created"
      ),
      counter("habit_tracker.habit.logged.count",
        tags: [:status],
        description: "Total number of habit logs created"
      ),
      counter("habit_tracker.email.sent.count",
        tags: [:type],
        description: "Total number of emails sent"
      ),
      counter("habit_tracker.email.failed.count",
        tags: [:type],
        description: "Total number of failed email deliveries"
      ),
      summary("habit_tracker.streak.calculation.duration",
        unit: {:native, :millisecond},
        description: "Time spent calculating streaks"
      ),
      
      # Oban metrics
      counter("oban.job.start.count",
        tags: [:worker],
        description: "Total number of jobs started"
      ),
      counter("oban.job.stop.count",
        tags: [:worker],
        description: "Total number of jobs completed"
      ),
      counter("oban.job.exception.count",
        tags: [:worker],
        description: "Total number of job failures"
      ),
      summary("oban.job.stop.duration",
        tags: [:worker],
        unit: {:native, :millisecond},
        description: "Job execution time"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {HabitTrackerWeb, :count_users, []}
    ]
  end
end
