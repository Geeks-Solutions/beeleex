defmodule Beeleex.InvoiceUpdate do
  @moduledoc """
  Work with Beelee Invoice update.
  """

  @type t :: %__MODULE__{
          cycle: cycle(),
          companyId: integer(),
          decimalPlaces: integer(),
          pricing: list(pricing()),
          created: String.t(),
          currency: String.t()
        }

  @type cycle :: %{
          id: integer(),
          type: String.t(),
          start: String.t()
        }

  @type pricing :: %{
          projectId: String.t(),
          projectName: String.t(),
          packagePriceBeforeTax: integer(),
          packageTax: integer(),
          packagePriceWithTax: integer(),
          packageTaxRate: integer(),
          packageName: String.t(),
          payAsYouGo: list(pay_as_you_go())
        }

  @type pay_as_you_go :: %{
          name: String.t(),
          description: String.t(),
          quantity: integer(),
          unitPriceBeforeTax: integer(),
          totalBeforeTax: integer(),
          tax: integer(),
          taxRate: integer(),
          totalWithTax: integer()
        }

  defstruct [
    :cycle,
    :companyId,
    :decimalPlaces,
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

  @doc """
  format the following data into a valid pricing map
  """
  @spec format_pricing(
          String.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          list(pay_as_you_go())
        ) :: pricing()
  def format_pricing(
        projectId,
        projectName,
        packagePriceBeforeTax,
        packageTax,
        packageTaxRate,
        packagePriceWithTax,
        packageName,
        payAsYouGo
      ) do
    %{
      projectId: projectId,
      projectName: projectName,
      packagePriceBeforeTax: packagePriceBeforeTax,
      packageTax: packageTax,
      packageTaxRate: packageTaxRate,
      packagePriceWithTax: packagePriceWithTax,
      packageName: packageName,
      payAsYouGo: payAsYouGo
    }
  end
end
