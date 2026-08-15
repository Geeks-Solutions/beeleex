# Installation & Configuration

## 1. Add the dependency

```elixir
# mix.exs
{:beeleex, git: "https://github.com/Geeks-Solutions/beeleex"}
```

## 2. Mount the routes

In your host app's `router.ex`:

```elixir
use Beeleex.Routes, scope: "/beeleex"
```

- `:scope` defaults to `"/beeleex"`.
- `:pipe_through` defaults to `[:beeleex_api]`; pass your own to add auth, e.g.
  `use Beeleex.Routes, scope: "/", pipe_through: [:browser, :authenticate]`.

This mounts `POST <scope>/verify_token` → `BeeleexController.verify_token`.
See [token-verification.md](token-verification.md).

To also mount the server-rendered billing pages, opt in with `live: true`:

```elixir
use Beeleex.Routes,
  live: true,
  scope: "/billing",
  live_pipe_through: [:require_admin]
```

See [integration/liveview-pages.md](integration/liveview-pages.md) for the full
LiveView setup, including session token, stylesheet and payment method
JavaScript hook wiring.

## 3. Add the webhook plug

In your host app's `endpoint.ex`, **before** `Plug.Parsers`:

```elixir
plug Beeleex.WebhookPlug,
  at: "/api/webhook/beeleex",
  secret: {Application, :get_env, [:beeleex, :business_unit_secure_key]},
  handler: MyApp.BeeleeHandler
```

See [webhooks-and-events.md](webhooks-and-events.md) for handler details and
the `at` / `secret` / `tolerance` options.

## 4. Application config

```elixir
# config/config.exs
config :beeleex,
  verify_token_action: %{module: YourModule, function: :function_name},
  business_unit_secure_key: "your bu secure key",
  business_unit_id: "your bu_id"
```

### Configuration keys

| Key | Required | Default | Purpose |
|-----|----------|---------|---------|
| `verify_token_action` | Yes (for token verification) | — | `%{module:, function:}` invoked to verify a token. |
| `business_unit_secure_key` | Yes | — | Secret used as webhook signing secret **and** the `secure-key` API header. |
| `business_unit_id` | Yes | — | Sent as the `bu-id` API header. |
| `beelee_endpoint` | No | `https://beelee.geeks.solutions/v0-1/api` | Beelee GraphQL endpoint. |
| `debug_on` | No | `false` | When `true`, `Beeleex.debug_variable/2` logs payloads at debug level. |
| `json_library` | No | `Jason` | JSON library (module, fun, or `{m, f, a}`). |
| `live_layout` | No | `{BeeleexWeb.Layouts, :live}` | Inner layout used by the LiveView pages. |
| `bu_token_session_key` | No | `"bu_token"` | Plug session key containing the signed-in user's Beelee token for LiveView pages. |
| `show_linked_projects` | No | `true` | Controls the linked-projects section on company details. |

> The `business_unit_secure_key` doubles as the webhook secret and the API
> `secure-key` header — keep it secret and load it from env in production
> (`config/runtime.exs`).

## Environments

`config/config.exs` imports the per-env file (`dev.exs`, `prod.exs`, `test.exs`)
at the bottom, and `runtime.exs` runs for all environments at boot (use it for
secrets from env vars). The bundled `BeeleexWeb.Endpoint` config is primarily
for running the library standalone in dev/test.
