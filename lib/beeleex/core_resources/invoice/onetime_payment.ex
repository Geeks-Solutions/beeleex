defmodule Beeleex.OnetimePayment do
  @moduledoc """
  Work with Beelee Onetime payment invoice.
  """
  alias Beeleex.InvoiceUpdate

  @type t :: %__MODULE__{
          companyId: integer,
          decimalPlaces: integer,
          pricing: list(InvoiceUpdate.pricing()),
          tags: list(String.t())
        }

  defstruct [
    :companyId,
    :decimalPlaces,
    :pricing,
    :tags
  ]
end
