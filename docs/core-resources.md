# Core Resources (Structs)

Domain types live under `lib/beeleex/core_resources/`. They are plain
`defstruct` modules with `@type t` definitions, populated from Beelee responses
(camelCase JSON → snake_case atoms, except a few input structs that keep
camelCase keys to match the GraphQL schema).

## Money convention

Monetary fields are **integers** combined with a `decimal_places` field — e.g.
`amount_with_tax: 1050`, `decimal_places: 2` represents `10.50`.

## `Beeleex.Event` — `core_resources/events.ex`
Webhook event envelope. Fields: `object`, `api_version`, `created`, `data`,
`type`. `data.object` is one of `InvoiceInitiation.t()`, `InvoiceUpdate.t()`, or
a raw map. See [webhooks-and-events.md](webhooks-and-events.md).

## `Beeleex.Company` — `core_resources/company.ex`
A customer company. Fields: `id`, `user_id`, `name`, `email`, `country`,
`projects_ids`, `vat_number`, `solvency_status`, `unlinked_project_id`,
`phone_number`, `address`, `business_unit`.
- `compute_bu_cycle/1` derives cycle data from `business_unit.job.scheduled_at`.

## `Beeleex.Invoice` — `core_resources/invoice/invoice.ex`
A Beelee invoice. Fields: `id`, `amount_before_tax`, `tax_amount`, `tax_rate`,
`amount_with_tax`, `reduction_amount_before_tax`, `reduction_tax_amount`,
`reduction_amount_with_tax`, `decimal_places`, `attempt`, `cycle`, `breakdown`
(`list(InvoiceUpdate.pricing())`), `beginning`, `end`, `closing_date`, `type`,
`company`, `status`, `inserted_at`.

## `Beeleex.InvoiceUpdate` — `core_resources/invoice/invoice_update.ex`
Payload for updating freshly-generated invoices (camelCase keys). Fields:
`cycle`, `companyId`, `decimalPlaces`, `pricing`, `created`, `currency`, `tags`.
Nested types: `cycle`, `pricing` (package + `payAsYouGo`), `pay_as_you_go`.
- `format_payload/1`, `format_pricing/…` shape the GraphQL input. Consumed by
  `Beeleex.Api.update_invoices/1`.

## `Beeleex.InvoiceInitiation` — `core_resources/invoice/invoice_initiation.ex`
The `invoice_initiation` webhook object. Fields: `cycle`, `cycle_begin`,
`cycle_end`, `cycle_type`, `companies`, `created`, `currency`, `inserted_at`.

## `Beeleex.InvoicePayment` — `core_resources/invoice/invoice_payment.ex`
Invoice payment attempt data. Fields include `invoice_amount`, `decimal_places`,
`invoice_id`, `invoice_creation`, `cycle`, `cycle_type`, `attempt`,
`last_attempt`, `correction`, `company`, `payment_method`,
`failed_payment_methods`, `remaining_unpaid_invoice_count`, `created`,
`currency`.

## `Beeleex.OnetimePayment` — `core_resources/invoice/onetime_payment.ex`
Input for a one-time invoice (camelCase keys). Fields: `companyId`,
`decimalPlaces`, `pricing` (`list(InvoiceUpdate.pricing())`), `tags`. Consumed
by `Beeleex.Api.generate_onetime_invoice/1`.

## `Beeleex.CreditNote` — `core_resources/invoice/credit_note.ex`
A credit note. Fields: `id`, `reason`, `status`, `amount`, `tags`,
`remaining_amount`, `originating_invoice` (`Invoice.t()`). Produced by
`Beeleex.Api.generate_credit_note/4`.

## `Beeleex.PaymentMethod` — `core_resources/payment_methods/payment_method.ex`
A payment method. Fields: `type`, `company`, `default`, `object`,
`other_methods`. `object` may be a `Card.t()`.

## `Beeleex.PaymentMethod.Card` — `core_resources/payment_methods/card.ex`
Card details (derives `Jason.Encoder`). Fields: `brand`, `last_four`,
`expiry_year`, `expiry_month`.

## `core_resources/payment_collection.ex`
Reserved module for payment-collection data (currently minimal).
