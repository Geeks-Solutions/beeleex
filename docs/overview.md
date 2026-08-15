# Overview

**Beeleex** is the Elixir/Phoenix client library that lets a host application
("Business Unit") integrate with the **Beelee** billing & invoicing platform
(`https://beelee.geeks.solutions`).

It provides three integration surfaces:

1. **Outbound API calls** — `Beeleex.Api` talks to the Beelee GraphQL server to
   create/update invoices, fetch companies, generate credit notes, etc.
2. **Inbound webhooks** — `Beeleex.WebhookPlug` receives signed events from
   Beelee (invoice & payment-method lifecycle) and routes them to a handler you
   implement.
3. **Token verification** — `Beeleex.Routes` + `BeeleexController` expose a
   `POST /verify_token` endpoint Beelee calls to authenticate your users and
   resolve requested profile fields.

## Tech stack

| Item | Value |
|------|-------|
| Language | Elixir `~> 1.12` |
| Framework | Phoenix `>= 1.5.0` |
| App name (OTP) | `:beeleex` |
| Version | `0.1.0` |
| JSON | Jason (`~> 1.4`, configurable) |
| HTTP server | `plug_cowboy ~> 2.5` |
| Shared helpers | `ex_geeks` (git dependency, Geeks-Solutions) |
| i18n | `gettext` |
| Telemetry | `telemetry_metrics`, `telemetry_poller` |
| Lint | `credo` (dev/test) |

## How it fits together

```
Your Phoenix app
 ├─ router.ex      use Beeleex.Routes          → POST /verify_token  (Beelee → you)
 ├─ endpoint.ex    plug Beeleex.WebhookPlug    → webhook events      (Beelee → you)
 ├─ config.exs     verify_token action + BU keys
 └─ Beeleex.Api.*  outbound GraphQL calls      (you → Beelee)
```

The library is meant to be added as a dependency to a host Phoenix application;
it ships its own minimal endpoint/supervision tree (used mainly for local dev
and tests) but the routes/plug are designed to be mounted into the host app.

See [architecture.md](architecture.md) for the module map.
