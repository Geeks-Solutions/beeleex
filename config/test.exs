import Config

# Run Beeleex's bundled endpoint so the LiveView test suite can reach the pages.
config :beeleex, start_endpoint: true

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :beeleex, BeeleexWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "jaWKVF4g81tycpRQ5m3zcu/cOHYPrsmAmYBG5tbropuQx6Wj5E2PeHmGw8jYJWLs",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
