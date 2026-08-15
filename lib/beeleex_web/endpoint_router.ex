defmodule BeeleexWeb.Router do
  @moduledoc """
  Router for Beeleex's own bundled endpoint (used for local development and the
  test suite). Host applications do **not** use this module — they mount the
  routes into their own router with `use Beeleex.Routes`.

  It mounts everything `Beeleex.Routes` offers (the `verify_token` API plus the
  billing LiveView pages) at the root scope, so the pages are reachable at e.g.
  `/companies` on the bundled endpoint.
  """
  use Phoenix.Router

  import Phoenix.Controller
  import Phoenix.LiveView.Router

  api_module =
    case Mix.env() do
      :dev -> BeeleexWeb.Dev.SampleApi
      :test -> Beeleex.ApiMock
      _ -> Beeleex.Api
    end

  use Beeleex.Routes, live: true, scope: "/", api_module: api_module
end
