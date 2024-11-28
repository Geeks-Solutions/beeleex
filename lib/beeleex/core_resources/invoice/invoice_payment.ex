defmodule Beeleex.InvoicePayment do
  @moduledoc """
  Work with Beeleex Invoice payment request.
  """

  @type t :: %__MODULE__{
    invoice_amount: integer,
    decimal_places: integer,
    invoice_id: integer,
    invoice_creation: String.t(),
    cycle: String.t(),
    cycle_type: String.t(),
    attempt: integer,
    last_attempt: boolean,
    correction: boolean,
    company: map,
    payment_method: Beeleex.PaymentMethod.t(),
    failed_payment_methods: List.t(Beelee.Notifications.PaymentMethod.t()),
    remaining_unpaid_invoice_count: integer,
    created: String.t(),
    currency: String.t()
  }

  defstruct [
    :invoice_amount,
    :decimal_places,
    :invoice_id,
    :invoice_creation,
    :cycle,
    :cycle_type,
    :attempt,
    :last_attempt,
    :correction,
    :company,
    :payment_method,
    :failed_payment_methods,
    :remaining_unpaid_invoice_count,
    :created,
    :currency
  ]

end
