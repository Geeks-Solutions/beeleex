defmodule Beeleex.Routes do
  @moduledoc """
  `Beeleex.Routes` mounts the routes Beeleex needs into your Phoenix router.

  ## Token verification API (always mounted)

  ```elixir
  use Beeleex.Routes, scope: "/", pipe_through: [:browser, :authenticate]
  ```

  `:scope` defaults to `"/beeleex"`.

  `:pipe_through` defaults to beeleex's `[:beeleex_api]`; the pipes you pass are
  appended, so you can customize the pipeline as you want.

  This always mounts:

  ```elixir
  post("/verify_token", BeeleexController, :verify_token, as: :beeleex)
  ```

  ## Billing LiveView pages (opt-in)

  Pass `live: true` to additionally mount the server-rendered billing pages:

  ```elixir
  use Beeleex.Routes, live: true, scope: "/billing"
  ```

  This mounts (under `:scope`):

  ```elixir
  live "/companies",          CompaniesLive.Index, :index
  live "/companies/new",      CompaniesLive.Show,  :new
  live "/companies/:id",      CompaniesLive.Show,  :show
  live "/companies/:id/edit", CompaniesLive.Show,  :edit

  live "/companies/:id/invoices/:invoice_id", InvoicesLive.Show, :show
  ```

  The pages fetch data server-side via `Beeleex.Api`, so configure
  `:business_unit_secure_key`, `:business_unit_id` and (optionally)
  `:beelee_endpoint` for your app.

  ### Options

  | Option | Applies to | Default |
  |--------|------------|---------|
  | `:scope` | all routes | `"/beeleex"` |
  | `:live` | mount the billing pages | `false` |
  | `:pipe_through` | the `verify_token` API route | `[]` |
  | `:live_pipe_through` | the billing pages (after `:beeleex_browser`) — use for auth | `[]` |
  | `:on_mount` | the billing `live_session` — assign `current_user`, guard, etc. | `[]` |
  | `:root_layout` | the billing `live_session` | `{BeeleexWeb.Layouts, :root}` |
  | `:live_session_name` | the `live_session` name | `:beeleex` |
  | `:api_module` | API implementation used by the billing LiveViews | `Beeleex.Api` |

  ### Embedding in your app's chrome (auth + layout)

  To put the pages behind your auth and inside your own dashboard layout:

  ```elixir
  use Beeleex.Routes,
    live: true,
    scope: "/billing",
    live_pipe_through: [:my_auth],
    on_mount: [MyAppWeb.AuthHook],
    root_layout: {MyAppWeb.Layouts, :root}
  ```

  Then point the pages' inner layout at a function of yours that renders your
  chrome around the content (wrap it in an element with class `beeleex` so the
  shipped stylesheet applies):

  ```elixir
  config :beeleex, :live_layout, {MyAppWeb.Layouts, :beeleex}
  ```

  ### Requirements for the host app

  * Your endpoint must serve the LiveView socket:
    `socket "/live", Phoenix.LiveView.Socket, ...`.
  * Make `priv/static/beeleex/beeleex.css` reachable (e.g.
    `plug Plug.Static, at: "/", from: :beeleex, only: ~w(beeleex)`).
  """

  defmacro __using__(options \\ []) do
    scoped = Keyword.get(options, :scope, "/beeleex")
    api_pipes = [:beeleex_api] ++ Keyword.get(options, :pipe_through, [])
    browser_pipes = [:beeleex_browser] ++ Keyword.get(options, :live_pipe_through, [])
    live? = Keyword.get(options, :live, false)
    live_session_name = Keyword.get(options, :live_session_name, :beeleex)
    api_module = Keyword.get(options, :api_module, Beeleex.Api)
    # root_layout / on_mount are kept as AST and unquoted directly so a host can
    # pass aliased modules (e.g. {MyAppWeb.Layouts, :root}) that resolve in its
    # own context. Defaults are plain terms, which unquote splices fine too.
    root_layout = Keyword.get(options, :root_layout, {BeeleexWeb.Layouts, :root})
    on_mount = Keyword.get(options, :on_mount, [])

    quote do
      import Phoenix.LiveView.Router

      pipeline :beeleex_browser do
        plug(:accepts, ["html", "json"])
        plug(:fetch_session)
        plug(:fetch_live_flash)
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

      if unquote(live?) do
        scope unquote(scoped), BeeleexWeb do
          pipe_through(unquote(browser_pipes))

          live_session unquote(live_session_name),
            root_layout: unquote(root_layout),
            on_mount: unquote(on_mount),
            session: %{"beeleex_api_module" => unquote(api_module)} do
            live("/companies", CompaniesLive.Index, :index)
            live("/companies/new", CompaniesLive.Show, :new)
            live("/companies/:id", CompaniesLive.Show, :show)
            live("/companies/:id/edit", CompaniesLive.Show, :edit)
            live("/companies/:id/invoices/:invoice_id", InvoicesLive.Show, :show)
          end
        end
      end
    end
  end
end
