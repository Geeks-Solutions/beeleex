defmodule Beeleex.Routes do
  @moduledoc """
  Beeleex.Routes must be used in your phoenix routes as follows:

  ```elixir
  use Beeleex.Routes, scope: "/", pipe_through: [:browser, :authenticate]
  ```

  `:scope` defaults to `"/beeleex"`

  `:pipe_through` defaults to beeleex's `[:beeleex_api]`, you can customize the pipeline as you want.

  The supported routes are:
  ```elixir
  post("/verify_token", BeeleexController, :verify_token, as: :beeleex)
  ```
  """

  # use Phoenix.Router

  defmacro __using__(options \\ []) do
    scoped = Keyword.get(options, :scope, "/beeleex")
    custom_pipes = Keyword.get(options, :pipe_through, [])
    api_pipes = [:beeleex_api] ++ custom_pipes

    quote do
      pipeline :beeleex_browser do
        plug(:accepts, ["html", "json"])
        plug(:fetch_session)
        plug(:fetch_flash)
        plug(:protect_from_forgery)
        plug(:put_secure_browser_headers)
      end

      pipeline :beeleex_api do
        plug(:accepts, ["json"])
      end

      scope unquote(scoped), BeeleexWeb do
        pipe_through(unquote(api_pipes))

        post("/verify_token", BeeleexController, :verify_token, as: :beeleex)
      end
    end
  end
end
