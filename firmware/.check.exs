[
  tools: [
    {:credo, "mix credo --strict"},
    # dialyzer fora do gate do firmware: PLT cross-target é custoso; roda no host manualmente
    {:dialyzer, false}
  ]
]
