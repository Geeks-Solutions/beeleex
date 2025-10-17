defmodule Beeleex.Invoice do
  @moduledoc """
  Work with Beelee Invoice struct
  """

  @type t :: %__MODULE__{
          id: integer(),
          amount_before_tax: integer(),
          tax_amount: integer(),
          tax_rate: integer(),
          amount_with_tax: integer(),
          reduction_amount_before_tax: integer(),
          reduction_tax_amount: integer(),
          reduction_amount_with_tax: integer(),
          decimal_places: integer(),
          attempt: integer(),
          cycle: integer(),
          breakdown: list(InvoiceUpdate.pricing()),
          beginning: String.t(),
          end: String.t(),
          closing_date: String.t(),
          type: String.t(),
          company: Beeleex.Company.t(),
          status: String.t(),
          inserted_at: String.t()
        }

  defstruct [
    :id,
    :amount_before_tax,
    :tax_amount,
    :tax_rate,
    :amount_with_tax,
    :reduction_amount_before_tax,
    :reduction_tax_amount,
    :reduction_amount_with_tax,
    :decimal_places,
    :attempt,
    :cycle,
    :breakdown,
    :beginning,
    :end,
    :closing_date,
    :type,
    :company,
    :status,
    :currency,
    :inserted_at
  ]
end
