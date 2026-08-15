defmodule Beeleex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # The bundled endpoint/PubSub/Telemetry exist only for Beeleex's own local
    # development and test suite. When Beeleex is used as a dependency in a host
    # app, the host serves the LiveView pages through its own endpoint, so we
    # must NOT start our endpoint (it would try to bind a port and clash).
    #
    # Enabled via `config :beeleex, start_endpoint: true` in Beeleex's own
    # dev/test config; absent (false) in host applications.
    children =
      if Application.get_env(:beeleex, :start_endpoint, false) do
        [
          BeeleexWeb.Telemetry,
          {Phoenix.PubSub, name: Beeleex.PubSub},
          BeeleexWeb.Endpoint
        ]
      else
        []
      end

    opts = [strategy: :one_for_one, name: Beeleex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is
  # updated (only relevant when the bundled endpoint is running).
  @impl true
  def config_change(changed, _new, removed) do
    if Application.get_env(:beeleex, :start_endpoint, false) do
      BeeleexWeb.Endpoint.config_change(changed, removed)
    end

    :ok
  end
end
