# AGENTS.md

**Beeleex** — Elixir/Phoenix client library for the **Beelee** billing &
invoicing platform. It provides outbound API calls, inbound signed webhooks, and
a token-verification endpoint for integrating a host Phoenix app ("Business
Unit") with Beelee.

This file is the table of contents for the project documentation under
[`docs/`](docs/). Start with the Overview, then jump to the area you need.

## Documentation index

| Doc | What's inside |
|-----|---------------|
| [docs/overview.md](docs/overview.md) | Purpose, tech stack, how the three integration surfaces fit together. |
| [docs/architecture.md](docs/architecture.md) | Directory layout, supervision tree, module responsibilities, data conventions. |
| [docs/configuration.md](docs/configuration.md) | Installation, mounting routes/plug, and all config keys. |
| [docs/api-reference.md](docs/api-reference.md) | `Beeleex.Api` outbound GraphQL functions (invoices, companies, credit notes). |
| [docs/webhooks-and-events.md](docs/webhooks-and-events.md) | `Beeleex.WebhookPlug`, signature verification, handler contract, event types. |
| [docs/token-verification.md](docs/token-verification.md) | `POST /verify_token` flow, verifier callback contract, responses. |
| [docs/core-resources.md](docs/core-resources.md) | Domain structs (Company, Invoice, CreditNote, PaymentMethod, …). |

## Quick reference

| Topic | Where |
|-------|-------|
| Required config keys | [configuration.md](docs/configuration.md) |
| Add the webhook plug | [webhooks-and-events.md](docs/webhooks-and-events.md) |
| Mount routes | [configuration.md](docs/configuration.md) / [token-verification.md](docs/token-verification.md) |
| Outbound calls | [api-reference.md](docs/api-reference.md) |
| Struct field lists | [core-resources.md](docs/core-resources.md) |

## Conventions for agents

- **Source of truth:** module `@moduledoc`/`@doc`/`@spec` annotations in `lib/`.
  When code and docs disagree, trust the code and update the relevant `docs/` page.
- **Money:** amounts are integers paired with a `decimal_places` field.
- **Keys:** Beelee responses are atomized + underscored
  (`ExGeeks.Helpers.atomize_keys`); some input structs intentionally keep
  camelCase keys to match the GraphQL schema.
- **Secrets:** `business_unit_secure_key` is both the webhook signing secret and
  the API `secure-key` header — load it from env in production.
