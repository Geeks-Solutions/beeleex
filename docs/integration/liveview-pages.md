# LiveView billing pages (Elixir-native)

These **Phoenix LiveView** pages let a host application that depends on
`beeleex` mount ready-made, server-rendered billing pages with a one-line router
macro — no SPA, no GraphQL client, and no Beelee tokens in the browser.

> **Status:** ships the **Companies** screens (list + details, including
> create/edit/delete and customer-project linking), the **Invoices** screens
> (per-company list + invoice detail), and **Payment methods** (per-company
> list with make-default / deactivate / retry, plus add-card via a Stripe
> JavaScript hook). All three are embedded in the company details page.

## How it works

```
Host LiveView (server)
  -> Beeleex.Api.get_companies(bu_token, ...) / get_company(bu_token, id) / ...
       ExGeeks.Helpers.endpoint_post_callback(url, %{query, variables}, ui_headers(token))
       ui_headers = bu-authorization (user's token) + bu-id   # per-user, never in browser
  -> Beelee GraphQL
```

The `bu_token` is the signed-in user's `user_portal` token. The LiveViews read
it server-side from the session via `BeeleexWeb.LiveSession.bu_token/1` (default
session key `"bu_token"`, override with `config :beeleex, :bu_token_session_key`)
and thread it into every `Beeleex.Api` call as `bu-authorization`. It is never
exposed to the browser. The host app must place that token in the Plug session
(e.g. in its auth pipeline) before the user reaches these pages.

The LiveViews use `Beeleex.Api` by default. Tests or local harnesses can inject
another module with the router macro's `:api_module` option.

## Mounting the pages

In your application's router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Beeleex.Routes, live: true, scope: "/billing", live_pipe_through: [:require_admin]
end
```

This mounts, under `:scope` (default `/beeleex`):

| Path | LiveView | Action |
|------|----------|--------|
| `GET /companies` | `BeeleexWeb.CompaniesLive.Index` | `:index` |
| `GET /companies/new` | `BeeleexWeb.CompaniesLive.Show` | `:new` |
| `GET /companies/:id` | `BeeleexWeb.CompaniesLive.Show` | `:show` |
| `GET /companies/:id/edit` | `BeeleexWeb.CompaniesLive.Show` | `:edit` |
| `GET /companies/:id/invoices/:invoice_id` | `BeeleexWeb.InvoicesLive.Show` | `:show` |

`POST /verify_token` is always mounted as well (see
[token-verification.md](../token-verification.md)).

### Macro options

| Option | Default | Meaning |
|--------|---------|---------|
| `:live` | `false` | Set `true` to mount the billing LiveView pages |
| `:scope` | `"/beeleex"` | URL scope for all mounted routes |
| `:pipe_through` | `[]` | Extra pipelines appended after `:beeleex_api` for `verify_token` |
| `:live_pipe_through` | `[]` | Extra pipelines appended after `:beeleex_browser` for the LiveView pages — use this to require authentication/authorization |
| `:on_mount` | `[]` | Hooks for the billing `live_session` |
| `:root_layout` | `{BeeleexWeb.Layouts, :root}` | Root layout for the `live_session`; pass your own to embed the pages in your app's chrome |
| `:api_module` | `Beeleex.Api` | Module used by the LiveView pages; useful for tests or the bundled dev harness |

The pages run through the macro-provided `:beeleex_browser` pipeline
(`fetch_session`, `fetch_live_flash`, `protect_from_forgery`,
`put_secure_browser_headers`). Append your own auth pipeline via `:live_pipe_through`.

## Host requirements

1. **LiveView socket** — your endpoint must serve it (standard for any LiveView
   app):

   ```elixir
   socket "/live", Phoenix.LiveView.Socket,
     websocket: [connect_info: [session: @session_options]]
   ```

2. **Configuration** — the same server-to-server credentials used by the rest of
   `Beeleex.Api`:

   ```elixir
   config :beeleex,
     beelee_endpoint: "https://beelee.geeks.solutions/v0-1/api",
     business_unit_id: System.get_env("BEELEE_BU_ID"),
     business_unit_secure_key: System.get_env("BEELEE_BU_SECURE_KEY")
   ```

3. **Styling** — include the shipped stylesheet and (optionally) theme it by
   overriding CSS variables. No Tailwind or build step required:

   ```html
   <link rel="stylesheet" href="/beeleex/beeleex.css" />
   ```

   ```css
   .beeleex { --bx-primary: #ff6a00; --bx-radius: 4px; }
   ```

   See [theming.md](theming.md) for the full variable list and how the
   `.beeleex`-scoped semantic classes work.

## API surface used

All added to `Beeleex.Api` (see [api-reference.md](../api-reference.md)) and
declared in the `Beeleex.ApiBehaviour`:

Each takes the user's `bu_token` as its first argument:

`get_companies/2`, `get_company/2`, `create_company/2`, `update_company/3`,
`delete_company/2`, `get_unlinked_projects/2`, `link_projects/3`,
`unlink_project/3`, `get_invoices/2`, `get_invoice/2`, `get_payment_methods/2`,
`request_setup_intent/2`, `deactivate_payment_method/2`,
`reactivate_payment_method/2`, `make_default_payment_method/3`.

These request only non-sensitive fields (they deliberately omit secrets such as
`stripeSecretKey` / `secureKey` present in the Beelee schema).

## JavaScript hook (payment methods only)

Adding a card requires the `BeeleexStripeSetup` hook to be registered with your
`LiveSocket`. The rest of the pages need no JavaScript beyond the standard
LiveView client.

```js
// assets/js/app.js
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { BeeleexHooks } from "../../deps/beeleex/priv/static/beeleex/beeleex_hooks.js"

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { ...BeeleexHooks }
})
```

No Stripe keys are configured in the host app: the publishable key comes from
Beelee via `request_setup_intent/2`, and Stripe.js is loaded on demand from
`https://js.stripe.com/v3`.

## Testing in your app

The pages are covered by `test/beeleex_web/live/companies_live_test.exs` using
`Phoenix.LiveViewTest` against a Mox mock of `Beeleex.ApiBehaviour`. To test your
own integration, mount the routes with `api_module: MyApp.BeeleexApiMock` and
define a mock with `Mox.defmock(MyApp.BeeleexApiMock, for: Beeleex.ApiBehaviour)`.

## Local development (see the pages)

`beeleex` ships a self-contained dev harness: a minimal endpoint
(`BeeleexWeb.Endpoint`) + router (`BeeleexWeb.Router`, mounting the macro at
`/`), a JS bundle (esbuild), and a sample-data API so the pages render without a
real Beelee BU.

```bash
mix deps.get
mix esbuild.install        # one-time: downloads the esbuild binary (for the JS bundle)
mix phx.server             # http://localhost:4000 (set PORT=4010 if 4000 is taken)
```

Then open:

* `http://localhost:4000/companies` — list
* `http://localhost:4000/companies/1` — details (with invoices + payment methods)
* `http://localhost:4000/companies/1/invoices/1001` — invoice detail

By default dev uses `BeeleexWeb.Dev.SampleApi` (canned data), wired through the
bundled router. To develop against a **real Beelee BU**, remove the
`api_module: BeeleexWeb.Dev.SampleApi` option in `BeeleexWeb.Router` and set
`:business_unit_secure_key`, `:business_unit_id` and `:beelee_endpoint`.

Host applications can also use the sample API in their own dev/test routers:

```elixir
use Beeleex.Routes,
  live: true,
  scope: "/billing",
  api_module: BeeleexWeb.Dev.SampleApi
```

`BeeleexWeb.Dev.SampleApi` is compiled from `dev/support`, which Beeleex includes
only for dependency `:dev` and `:test` compilation. It is not compiled in `:prod`,
so it is not part of a production release compiled with `MIX_ENV=prod`.

The pages are styled out of the box via the shipped `/beeleex/beeleex.css`
(see [theming.md](theming.md)); only the JavaScript bundle is built (esbuild).
