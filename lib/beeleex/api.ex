defmodule Beeleex.Api do
@moduledoc """
This is in charge of interfacing with the Beelee GraphQL server
To update data from Business Units to the Billing Center
"""
  require Logger
  defp url do
    Application.get_env(:beeleex, :beelee_endpoint, "https://beelee.geeks.solutions/v1/api")
  end

  defp headers do
    [
      {"content-type", "application/json"},
      {"secure-key", Application.get_env(:beeleex, :business_unit_secure_key)},
      {"bu-id", Application.get_env(:beeleex, :business_unit_id)}
    ]
  end
  def update_invoices(invoices) when is_list(invoices) do

    company_invoices = Enum.map(invoices, &(Beeleex.InvoiceUpdate.format_payload(&1)))

      case ExGeeks.Helpers.endpoint_post_callback(
        url(),
        %{
          query: """
          mutation updateCompanyInvoices($companyInvoices: [InvoiceInput]) {
            updateCompanyInvoices(companyInvoices: $companyInvoices) {
              message
            }
          }
          """,
          variables: %{
            companyInvoices: company_invoices
          }
        },
        headers()
      ) do
        %{"data" => %{"updateCompanyInvoices" => %{"message" => message}}} ->
          {:ok, message}
        %{"data" => _, "errors" => errors} ->
          error = List.first(errors)["message"]
          Logger.error("#{__ENV__.function|>elem(0)}: #{error}")
          {:error, error}
      end
  end

end
