import Config

config :cachetastic, :backends,
  primary: :redis,
  redis: [host: "localhost", port: 6379],
  ets: [],
  fault_tolerance: [primary: :redis, backup: :ets]

import_config "#{config_env()}.exs"
