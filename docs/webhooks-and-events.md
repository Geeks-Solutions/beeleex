# Webhooks & Events

Beelee communicates lifecycle changes to your Business Unit via signed
webhooks. `Beeleex.WebhookPlug` receives them, verifies the signature, and
dispatches a `Beeleex.Event` struct to your handler.

## Mounting the plug

Add to your host app's `endpoint.ex`, **before** `Plug.Parsers` runs (the body
must be readable raw):

```elixir
plug Beeleex.WebhookPlug,
  at: "/api/webhook/beeleex",
  handler: MyAppWeb.Billing.BeeleeHandler,
  secret: {Application, :get_env, [:beeleex, :business_unit_secure_key]}
```

### Options

| Option | Description |
|--------|-------------|
| `at` | URL path to listen on; must match the webhook configured in the Beelee dashboard. |
| `handler` | Module implementing `handle_event/1`. You create this. |
| `secret` | Webhook signing secret. Accepts a binary, a `fn -> ... end`, or an MFA tuple `{m, f, a}` for runtime config. |
| `tolerance` | Optional max age (seconds) for the event; defaults to `300`. |

## Signature verification

`Beeleex.Webhook.construct_event/4` validates the `beelee-signature` header
using the `v1` HMAC scheme and a default tolerance of **300 seconds** before
returning `{:ok, %Beeleex.Event{}}` or `{:error, reason}`. Requests with no
signature get a `400` ("Secure your call with a valid signature…").

## Request flow (`WebhookPlug.call/2`)

1. Matches `POST` requests on the configured `path_info`.
2. Resolves the secret (`parse_secret!/1`).
3. Reads `beelee-signature` header + raw body.
4. `construct_event/…` verifies and builds the event.
5. Calls `handler.handle_event/1`.
6. `200 ""` on success; `400 <reason>` on any failure.

## Implementing a handler

`handle_event/1` receives a `%Beeleex.Event{}` and must return one of:

| Return | Meaning |
|--------|---------|
| `:ok` / `{:ok, term}` | Event processed → `200`. |
| `{:error, reason}` (atom or binary) | Rejected → `400` with reason. |
| `:error` | Rejected → `400` empty body. |
| anything else | Raises (invalid response contract). |

```elixir
defmodule MyAppWeb.BeeleeHandler do
  def handle_event(%Beeleex.Event{type: "invoice_initiation"} = event) do
    # handle new-cycle invoices
    :ok
  end

  def handle_event(%Beeleex.Event{type: "payment_method_added"} = event), do: :ok

  def handle_event(_event), do: :ok
end
```

You only need to implement the events you care about — fall through with
`handle_event(_event), do: :ok`.

## Event types

| `type` | When it occurs |
|--------|----------------|
| `invoice_initiation` | A new cycle ran and invoices were generated. |
| `invoice_payment_succeeded` | An invoice was successfully paid. |
| `invoice_payment_failed` | An invoice payment attempt failed. |
| `payment_method_added` | A new payment method was added to a company. |
| `payment_method_add_failed` | Adding a new payment method failed. |
| `payment_method_expire_2M` | A payment method expires in 2 months. |
| `payment_method_expire_1M` | A payment method expires in 1 month. |
| `payment_method_update` | A payment method was updated. |
| `payment_method_expiry_1_left` | A method expired; only one valid method remains. |
| `payment_method_expiry_0_left` | The last payment method expired. |
| `company_update` | The company was updated by the system (e.g. became insolvent). |

The `%Beeleex.Event{}` struct carries `:type`, `:data`, `:object`, `:created`,
`:api_version`. `Beeleex.Converter` maps the inner object's `"type"` to the
matching struct (e.g. `Beeleex.InvoiceInitiation`). See
[core-resources.md](core-resources.md).
