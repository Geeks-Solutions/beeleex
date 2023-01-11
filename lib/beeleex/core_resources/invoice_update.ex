defmodule Beeleex.InvoiceUpdate do
  @moduledoc """
  Work with Beelee Invoice update.
  """

  @type t :: %__MODULE__{
    cycle: cycle(),
    companyId: integer,
    pricing: list(pricing()),
    created: String.t(),
    currency: String.t()
  }

  @type cycle :: %{
    id: integer,
    type: String.t(),
    start: String.t()
  }

  @type pricing :: %{
    projectId: String.t(),
    projectName: String.t(),
    packagePriceBeforeTax: float,
    packageTax: float,
    packagePriceWithTax: float,
    packageName: String.t(),
    payAsYouGo: list(pay_as_you_go())
  }

  @type pay_as_you_go :: %{
    name: String.t(),
    description: String.t(),
    quantity: integer,
    unitPriceBeforeTax: float,
    totalBeforeTax: float,
    tax: float,
    totalWithTax: float
  }

  defstruct [
    :cycle,
    :companyId,
    :pricing,
    :created,
    :currency
  ]
  def format_payload(%Beeleex.InvoiceUpdate{} = invoice_update) do
    invoice_update
    |> Map.from_struct()
    |> Map.put(:cycleId, invoice_update.cycle.id)
    |> Map.drop([:cycle, :created, :currency])
  end

end
