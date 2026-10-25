# Applied legacy migrations are immutable, including their original formatting.
# Add new migration filenames here when extending the journal schema.
[
  import_deps: [:ecto_sql],
  inputs: ["20261025000000_create_health_journal.exs"]
]
