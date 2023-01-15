defmodule Beeleex.InvoicePayment do
  @moduledoc """
  Work with Beeleex Invoice payment request.
  """

  @type t :: %__MODULE__{
    invoice_amount: float,
    invoice_id: integer,
    invoice_creation: String.t(),
    cycle: String.t(),
    cycle_type: String.t(),
    attempt: integer,
    correction: boolean,
    companies: map,
    payment_method: Beeleex.PaymentMethod.t(),
    failed_payment_methods: List.t(Beelee.Notifications.PaymentMethod.t()),
    created: String.t(),
    currency: String.t()
  }

  defstruct [
    :invoice_amount,
    :invoice_id,
    :invoice_creation,
    :cycle,
    :cycle_type,
    :attempt,
    :correction,
    :companies,
    :payment_method,
    :failed_payment_methods,
    :created,
    :currency
  ]

end
