import Config

config :cachetastic, Cachetastic.TestRepo,
  username: "postgres",
  password: "postgres",
  database: "my_app_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :cachetastic, ecto_repos: [Cachetastic.TestRepo]

config :logger, level: :error
