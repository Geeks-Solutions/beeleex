defmodule Beeleex.PaymentMethod do
  @moduledoc """
  Work with Beelee Payment Method request.
  """

  @type object ::
    Beeleex.Card.t()
    | map

  @type t :: %__MODULE__{
    type: String.t(),
    company: Beeleex.Company.t() | map,
    default: boolean,
    object: object,
    other_methods: map
  }

  defstruct [
   :type,
   :company,
   :default,
   :object,
   :other_methods
  ]
end
