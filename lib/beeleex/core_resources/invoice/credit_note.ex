defmodule Beeleex.CreditNote do
  @moduledoc """
  The Beelee CreditNote struct
  """
  @type t :: %__MODULE__{
          id: integer(),
          reason: String.t(),
          status: String.t(),
          amount: integer(),
          tags: list(String.t()),
          remaining_amount: integer(),
          originating_invoice: Invoice.t()
        }

  defstruct [
    :id,
    :reason,
    :status,
    :amount,
    :tags,
    :remaining_amount,
    :originating_invoice
  ]
end
