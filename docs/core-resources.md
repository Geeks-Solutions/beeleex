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

## `Beeleex.BusinessUnit` — `core_resources/business_unit.ex`
A Beelee Business Unit. Fields: `id`, `archived`, `billing_center`,
`current_cycle`, `cycle`, `invoices_count`, `job`, `name`, `secure_key`,
`start_cycle_date`, `token_validation_url`, `verify_card_attachment`,
`dev_mode`, `webhook_url`. Produced by `Beeleex.Api.edit_business_unit/2`.

## `Beeleex.Invoice` — `core_resources/invoice/invoice.ex`
A Beelee invoice. Fields: `id`, `amount_before_tax`, `tax_amount`, `tax_rate`,
`amount_with_tax`, `reduction_amount_before_tax`, `reduction_tax_amount`,
`reduction_amount_with_tax`, `decimal_places`, `attempt`, `cycle`, `breakdown`
(`[Invoice.package_line()]`), `beginning`, `end`, `closing_date`, `type`,
`tags`, `company`, `status`, `inserted_at`. Accounting fields:

- `invoice_number`, `invoice_reference`, `currency`, `issued_at`,
  `tax_point_date`, `due_date`, `accounting_data_status`, `outstanding_amount`.
- `seller_snapshot`, `buyer_snapshot`: immutable maps with `source_id`, `name`,
  `address` (street number/name, postal code, city, country), `vat_number`,
  `registration_number`. Never substitute the live `company` association.
- `seller_currency`, `seller_decimal_places`, `exchange_rate`,
  `seller_amount_before_tax`, `seller_tax_amount`, `seller_amount_with_tax`.

Amounts use integer minor units or exact base-10 integer strings with the stored
scale. FX is an exact decimal string (reporting units per invoice unit).
Unknown fields are `nil`; original totals are distinct from credited amounts
and the outstanding balance. The invoice number is a BigInteger string, not
the database ID. A complete issued invoice can be unnumbered.

`company` is a `Beeleex.Company` struct populated with the selected `id` and
`name`, or `nil` when missing. It represents the current company, separate
from the stored buyer snapshot.

`breakdown` maps retain package/project names and description, package net unit
price (quantity one), tax rate, tax and gross; nested `pay_as_you_go` maps retain
name/description, quantity, net unit price, net/tax/gross and tax rate.
Tax rates are basis points (2000 = 20%), independent of currency scale.

`tags` is the original list of
strings from Beelee (`[]` for an empty list, `nil` if absent or null).

## `Beeleex.InvoiceUpdate` — `core_resources/invoice/invoice_update.ex`
Payload for updating freshly-generated invoices (camelCase keys). Fields:
`cycle`, `companyId`, `decimalPlaces`, `pricing`, `created`, `currency`,
`exchangeRate`, `taxPointDate`, `tags`.
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
`decimalPlaces`, `currency`, `exchangeRate`, `taxPointDate`,
`pricing` (`list(InvoiceUpdate.pricing())`), `tags`. Consumed
by `Beeleex.Api.generate_onetime_invoice/1`.

## `Beeleex.CreditNote` — `core_resources/invoice/credit_note.ex`
A credit note. Fields: `id`, `reason`, `status`, `amount`, `tags`,
`remaining_amount`, `originating_invoice` (a map of selected invoice fields,
including tags when returned by Beelee). Produced by `Beeleex.Api.generate_credit_note/4`.

## `Beeleex.PaymentMethod` — `core_resources/payment_methods/payment_method.ex`
A payment method. Fields: `type`, `company`, `default`, `object`,
`other_methods`. `object` may be a `Card.t()`.

## `Beeleex.PaymentMethod.Card` — `core_resources/payment_methods/card.ex`
Card details (derives `Jason.Encoder`). Fields: `brand`, `last_four`,
`expiry_year`, `expiry_month`.

## `core_resources/payment_collection.ex`
Reserved module for payment-collection data (currently minimal).
