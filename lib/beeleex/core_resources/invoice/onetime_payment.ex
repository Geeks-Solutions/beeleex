defmodule Beeleex.OnetimePayment do
  @moduledoc """
  Work with Beelee Onetime payment invoice.
  """
  alias Beeleex.InvoiceUpdate

  @type t :: %__MODULE__{
          companyId: integer,
          decimalPlaces: integer,
          pricing: list(InvoiceUpdate.pricing()),
          tags: list(String.t()),
          currency: String.t() | nil,
          exchangeRate: String.t() | nil,
          taxPointDate: Date.t() | String.t() | nil
        }

  defstruct [
    :companyId,
    :decimalPlaces,
    :pricing,
    :tags,
    :currency,
    :exchangeRate,
    :taxPointDate
  ]

  def format_payload(%__MODULE__{} = input) do
    input
    |> Map.from_struct()
    |> InvoiceUpdate.format_accounting_fields()
  end

  def format_payload(input), do: input
end
