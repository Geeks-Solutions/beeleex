defmodule Beeleex.InvoiceInitiation do
  @moduledoc """
  Work with Beelee Invoice initiation request.
  """

  @type t :: %__MODULE__{
          cycle: String.t(),
          cycle_begin: String.t(),
          cycle_end: String.t(),
          cycle_type: String.t(),
          companies: map,
          created: String.t(),
          currency: String.t(),
          inserted_at: String.t()
        }

  defstruct [
    :cycle,
    :cycle_begin,
    :cycle_end,
    :cycle_type,
    :companies,
    :created,
    :currency,
    :inserted_at
  ]
end
