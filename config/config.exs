# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :beeleex, BeeleexWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: BeeleexWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Beeleex.PubSub,
  live_view: [signing_salt: "eCVM92TL"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Bundles the bundled dev endpoint's JavaScript (LiveView client + Beeleex
# hooks). Only used for local development of this library.
config :esbuild,
  version: "0.21.5",
  beeleex: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
