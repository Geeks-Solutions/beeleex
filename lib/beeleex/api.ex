defmodule Beeleex.Api do
  @moduledoc """
  This is in charge of interfacing with the Beelee GraphQL server
  To update data from Business Units to the Billing Center
  """
  require Logger

  defp url do
    Application.get_env(:beeleex, :beelee_endpoint, "https://beelee.geeks.solutions/v0-1/api")
  end

  defp headers do
    [
      {"content-type", "application/json"},
      {"secure-key", Application.get_env(:beeleex, :business_unit_secure_key)},
      {"bu-id", Application.get_env(:beeleex, :business_unit_id)}
    ]
  end

  @spec update_invoices(list(Beeleex.InvoiceUpdate.t())) ::
          {:ok, String.t()} | {:error, String.t()}
  def update_invoices(invoices) when is_list(invoices) do
    company_invoices = Enum.map(invoices, &Beeleex.InvoiceUpdate.format_payload(&1))

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
        Logger.error("#{__ENV__.function |> elem(0)}: #{error}")
        {:error, error}
    end
  end

  @spec get_company_by_customer_project(String.t()) ::
          {:ok, Beeleex.Company.t()} | {:error, String.t()}
  def get_company_by_customer_project(customer_project) do
    case ExGeeks.Helpers.endpoint_post_callback(
           url(),
           %{
             query: """
             query getcompany($customer_project:String!){
               getCompanyByCustomerProject(customerProject:$customer_project) {
                   address{
                     city
                     country
                     postalCode
                     streetName
                   }
                   name
                   email
                   phoneNumber
                   customerProjects
                   vatNumber
                   businessUnit{
                     id
                     archived
                     name
                     billingCenter{
                       name
                       id
                       vatNumber
                     }
                     cycle
                     job{
                       scheduledAt
                     }
                   }
                   userId
                   id
                   solvencyStatus
                 }}
             """,
             variables: %{
               customer_project: customer_project
             }
           },
           headers()
         ) do
      %{"data" => %{"getCompanyByCustomerProject" => company}} ->
        company
        |> ExGeeks.Helpers.atomize_keys(transformer: &Macro.underscore/1)
        |> Beeleex.Company.compute_bu_cycle()
        |> then(fn company -> {:ok, struct(Beeleex.Company, company)} end)

      %{"data" => _, "errors" => errors} ->
        error = List.first(errors)["message"]
        Logger.error("#{__ENV__.function |> elem(0)}: #{error}")
        {:error, error}
    end
  end

  @spec generate_onetime_invoice(Beeleex.OnetimePayment.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def generate_onetime_invoice(onetime_payment) do
    case ExGeeks.Helpers.endpoint_post_callback(
           url(),
           %{
             query: """
             mutation generateInvoice($onetimeInvoice: OnetimeInvoiceInput) {
               generateOnetimeInvoice(companyInvoice: $onetimeInvoice) {
                 message
               }
             }
             """,
             variables: %{
               onetimeInvoice: onetime_payment
             }
           },
           headers()
         ) do
      %{"data" => %{"generateOnetimeInvoice" => %{"message" => message}}} ->
        {:ok, message}

      %{"data" => _, "errors" => errors} ->
        error = List.first(errors)["message"]
        Logger.error("#{__ENV__.function |> elem(0)}: #{error}")
        {:error, error}
    end
  end
end
