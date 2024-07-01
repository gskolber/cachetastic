import Config

config :cachetastic, :backends,
  primary: :redis,
  redis: [host: "localhost", port: 6379],
  ets: []
