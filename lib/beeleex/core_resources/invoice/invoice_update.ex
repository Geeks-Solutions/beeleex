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
          currency: String.t(),
          exchangeRate: String.t() | nil,
          taxPointDate: Date.t() | String.t() | nil,
          tags: list(String.t())
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
    :currency,
    :exchangeRate,
    :taxPointDate,
    :tags
  ]

  def format_payload(%Beeleex.InvoiceUpdate{} = invoice_update) do
    invoice_update
    |> Map.from_struct()
    |> Map.put(:cycleId, invoice_update.cycle.id)
    |> Map.drop([:cycle, :created, :currency, :exchangeRate, :taxPointDate])
  end

  @doc "Builds the opt-in issuance payload without converting the FX rate to a float."
  def format_issuance_payload(%__MODULE__{} = input) do
    input
    |> format_payload()
    |> Map.put(:currency, input.currency)
    |> put_optional(:exchangeRate, input.exchangeRate)
    |> put_optional(:taxPointDate, format_tax_point(input.taxPointDate))
  end

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  defp format_tax_point(%Date{} = date), do: Date.to_iso8601(date)
  defp format_tax_point(value), do: value

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
