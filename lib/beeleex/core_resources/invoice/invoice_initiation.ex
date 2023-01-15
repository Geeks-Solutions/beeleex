defmodule Beeleex.InvoiceInitiation do
  @moduledoc """
  Work with Beelee Invoice initiation request.
  """

  @type t :: %__MODULE__{
    cycle: String.t(),
    cycle_ts: String.t(),
    cycle_type: String.t(),
    companies: map,
    created: String.t(),
    currency: String.t()
  }

  defstruct [
    :cycle,
    :cycle_ts,
    :cycle_type,
    :companies,
    :created,
    :currency
  ]

end
