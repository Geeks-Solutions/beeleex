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
          currency: String.t() | nil,
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
    |> Map.drop([:cycle, :created])
    |> format_accounting_fields()
  end

  @doc false
  def format_accounting_fields(payload) do
    payload
    |> Map.update(:taxPointDate, nil, &format_tax_point/1)
    |> Map.reject(fn {key, value} ->
      key in [:currency, :exchangeRate, :taxPointDate] and is_nil(value)
    end)
  end

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
