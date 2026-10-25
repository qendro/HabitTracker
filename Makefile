.PHONY: db setup dev test check assets

db:
	docker compose --project-name health-journal-dev --file docker/compose.dev.yml up -d
setup:
	mix setup
dev:
	mix phx.server
assets:
	mix assets.build
test:
	mix test
check:
	mix format --check-formatted
	mix compile --warnings-as-errors
	mix test
