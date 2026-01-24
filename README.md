# Habit Tracker

A production-ready habit tracking web application built with Elixir Phoenix + LiveView.

Track your daily habits, build streaks, and achieve your goals with an intuitive, mobile-first interface.

## ✨ Features

- **Flexible Habit Types**: Binary (done/not done), numeric (with targets), and duration tracking
- **Smart Scheduling**: Daily or weekday-specific habit schedules
- **Streak Tracking**: Automatic streak calculation with timezone awareness
- **Time Travel**: Log habits for past, present, or future dates
- **Email Reminders**: Configurable daily reminders via Resend
- **Admin Dashboard**: System metrics and user management
- **Mobile Optimized**: Responsive design with swipe gestures
- **Dark Mode**: Light and dark theme support

## 📁 Project Structure

```
habit-tracker/
├── assets/              # Frontend assets (JS, CSS)
├── bin/                 # Deployment scripts
├── config/              # Application configuration
├── docker/              # Docker configuration files
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── Dockerfile.dev
├── docs/                # Documentation
│   ├── ARCHITECTURE.md
│   └── DEVELOPMENT.md
├── lib/
│   ├── habit_tracker/           # Business logic contexts
│   │   ├── accounts/            # User authentication
│   │   ├── admin/               # Admin functionality
│   │   ├── reminders/           # Email reminders
│   │   ├── tracker/             # Habit tracking
│   │   └── workers/             # Background jobs
│   └── habit_tracker_web/       # Web interface
│       ├── components/          # Reusable UI components
│       ├── controllers/         # HTTP controllers
│       └── live/                # LiveView modules
├── priv/
│   ├── repo/migrations/         # Database migrations
│   └── static/                  # Static assets
├── scripts/             # Helper scripts
│   └── create_admin.sh
├── test/                # Test files
└── mix.exs              # Project configuration
```

## 🚀 Quick Start

### Using Docker (Recommended)

```bash
# Start the application
docker compose -f docker/docker-compose.yml up

# In another terminal, create an admin account
docker compose -f docker/docker-compose.yml exec web mix create_admin admin@example.com YourSecurePassword
```

The application will be available at http://localhost:4000

**Note**: Docker Compose file is located at `docker/docker-compose.yml`. You can optionally copy `.env.dev` to `.env` to customize environment variables.

### Without Docker

```bash
# Copy environment template
cp .env.dev .env

# Edit .env with your database settings

# Install dependencies
mix setup

# Start the server
mix phx.server
```

Visit http://localhost:4000

## 📚 Documentation

- **[DEVELOPMENT.md](docs/DEVELOPMENT.md)** - Complete development guide including setup, testing, deployment, and troubleshooting
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Technical architecture, database schema, and design decisions
- **[Spec Files](.kiro/specs/habit-tracker/)** - Detailed requirements, design, and implementation tasks

## ⚙️ Configuration

Environment variables are configured via:
- **Development**: `.env` file (copy from `.env.dev` template)
- **Production**: Gigalixir config (see DEVELOPMENT.md)

## 🏗️ Architecture

**Stack:**
- Backend: Elixir 1.15+ with Phoenix 1.8+ and LiveView
- Database: PostgreSQL 15+
- Styling: Tailwind CSS 4.x
- Email: Resend API via Swoosh
- Background Jobs: Oban
- Deployment: Gigalixir
- Error Tracking: Sentry

**Key Design Principles:**
- Timezone-aware date calculations
- Sparse storage (only explicit logs)
- Mobile-first responsive design
- Defense-in-depth security

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed technical documentation.

## 🧪 Testing

```bash
# With Docker
docker compose -f docker/docker-compose.yml run --rm test

# Without Docker
mix test

# Run precommit checks
mix precommit
```

## 🚢 Deployment

This application deploys to Gigalixir with automated deployment scripts:

```bash
# Deploy to staging
./bin/deploy_staging.sh

# Deploy to production (with safety checks)
./bin/deploy_production.sh
```

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for complete deployment instructions.

## 🔒 Security

Comprehensive security implementation:
- Bcrypt password hashing (cost 12)
- Rate limiting on authentication endpoints
- CSRF protection on all forms
- SQL injection prevention via Ecto
- Input validation and sanitization
- Secure session management
- Admin action audit logging

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for security details.

## 🤝 Contributing

1. Create a feature branch
2. Make your changes and add tests
3. Run `make precommit` to ensure all checks pass
4. Submit a pull request

## 📂 Quick Reference

**Common Commands:**
```bash
make setup          # Initial setup
make up             # Start services
make test           # Run tests
make create-admin   # Create admin account
make help           # See all commands
```

**File Locations:**
- Docker configs: `docker/`
- Documentation: `docs/`
- Helper scripts: `scripts/`
- Deployment scripts: `bin/`

## 📊 Project Status

This project follows a spec-driven development approach. See `.kiro/specs/habit-tracker/tasks.md` for implementation progress.

**Current Status:** Production-ready with core features complete. See tasks.md for remaining optional enhancements.

## 📝 License

[Add your license here]

## 🔗 Resources

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
- [Ecto](https://hexdocs.pm/ecto/)
- [Elixir](https://elixir-lang.org/)
- [Tailwind CSS](https://tailwindcss.com/)
