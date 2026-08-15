# Architecture

## Directory layout

```
lib/
├── beeleex.ex                     # Top-level helpers (debug_variable/2, json_library/0)
├── beeleex_web.ex                 # __using__ macros for controllers/views/router
├── beeleex/
│   ├── api.ex                     # Outbound GraphQL calls to Beelee
│   ├── application.ex             # OTP Application / supervision tree
│   ├── converter.ex               # Maps Beelee "type" → struct module
│   ├── helpers.ex                 # env/2 and misc helpers
│   ├── webhook.ex                 # Signature verification + event construction
│   ├── plugs/
│   │   └── beeleex_webhook.ex     # Beeleex.WebhookPlug — webhook entry point
│   └── core_resources/           # Domain structs (see core-resources.md)
│       ├── events.ex             # Beeleex.Event
│       ├── company.ex            # Beeleex.Company (+ compute_bu_cycle/1)
│       ├── payment_collection.ex
│       ├── payment_methods/      # PaymentMethod, PaymentMethod.Card
│       └── invoice/              # Invoice, InvoiceUpdate, InvoiceInitiation,
│                                 # InvoicePayment, OnetimePayment, CreditNote
└── beeleex_web/
    ├── endpoint.ex                # Phoenix endpoint
    ├── router.ex                  # Beeleex.Routes (use-able macro)
    ├── telemetry.ex
    ├── gettext.ex
    ├── controllers/
    │   └── beeleex_controller.ex  # verify_token action
    └── views/
        ├── beeleex_view.ex        # user_verified.json / error.json
        ├── error_view.ex
        └── error_helpers.ex
config/   config.exs, dev.exs, prod.exs, test.exs, runtime.exs
priv/     gettext translations
test/     conn_case support + error_view_test
```

## Supervision tree

`Beeleex.Application.start/2` (strategy `:one_for_one`, name `Beeleex.Supervisor`)
starts:

- `BeeleexWeb.Telemetry`
- `{Phoenix.PubSub, name: Beeleex.PubSub}`
- `BeeleexWeb.Endpoint`

## Module responsibilities

| Module | Role |
|--------|------|
| `Beeleex` | Library-wide helpers: `debug_variable/2` (logs when `:debug_on`), `json_library/0`. |
| `Beeleex.Api` | All outbound GraphQL mutations/queries. See [api-reference.md](api-reference.md). |
| `Beeleex.Webhook` | Verifies the `Beelee-Signature` header (HMAC `v1` scheme, 300s tolerance) and builds a `Beeleex.Event`. |
| `Beeleex.WebhookPlug` | Plug mounted in host `endpoint.ex`; reads body, verifies, calls `handler.handle_event/1`. See [webhooks-and-events.md](webhooks-and-events.md). |
| `Beeleex.Converter` | Converts a Beelee object map (keyed by `"type"`) into the matching struct (e.g. `"invoice_initiation" → Beeleex.InvoiceInitiation`). |
| `Beeleex.Routes` | `__using__` macro injecting `:beeleex_browser`/`:beeleex_api` pipelines and the `verify_token` route. |
| `BeeleexWeb.BeeleexController` | Implements `verify_token`. See [token-verification.md](token-verification.md). |
| `Beeleex.Helpers` | `env/2` config reader (supports `%{raise: true}`) and shared utilities. |
| `core_resources/*` | Plain `defstruct` domain types with `@type t`. |

## External data conventions

- Responses from Beelee are run through `ExGeeks.Helpers.atomize_keys(transformer: &Macro.underscore/1)`
  so camelCase JSON keys become snake_case atoms before being `struct/2`-ed.
- Monetary amounts are **integers** paired with a `decimal_places` field
  (e.g. amount `1050`, decimal_places `2` → `10.50`).
- GraphQL errors are logged via `Logger.error` and returned as `{:error, message}`.
