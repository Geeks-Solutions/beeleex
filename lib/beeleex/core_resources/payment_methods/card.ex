defmodule Beeleex.PaymentMethod.Card do
  @moduledoc """
  Work with Beelee Payment Method card type.
  """

  @type t :: %__MODULE__{
    brand: String.t(),
    last_four: integer,
    expiry_year: integer,
    expiry_month: integer
  }

  @derive Jason.Encoder
  defstruct [
    :brand,
    :last_four,
    :expiry_year,
    :expiry_month
  ]
end
