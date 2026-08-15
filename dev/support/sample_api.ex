defmodule BeeleexWeb.Dev.SampleApi do
  @moduledoc """
  In-memory implementation of `Beeleex.ApiBehaviour` returning canned data.

  Used **only** for local development so the bundled endpoint can render the
  LiveView pages without a real Beelee Business Unit. It is compiled from
  `dev/support` only in `:dev` and wired by `BeeleexWeb.Router`.

  To develop against a real Beelee BU instead, remove the `api_module:
  BeeleexWeb.Dev.SampleApi` option from `BeeleexWeb.Router` and configure
  `:business_unit_secure_key` / `:business_unit_id` / `:beelee_endpoint`.
  """
  @behaviour Beeleex.ApiBehaviour

  alias Beeleex.Company
  alias Beeleex.Invoice

  @companies [
    %Company{
      id: 1,
      name: "Acme Inc",
      email: "billing@acme.test",
      phone_number: "+1 555 0100",
      vat_number: "VAT123",
      registration_number: "REG999",
      solvency_status: "solvent",
      invoices_count: 2,
      payment_methods_count: 1,
      customer_projects: ["proj-acme-1", "proj-acme-2"],
      address: %{
        city: "Paris",
        country: "FR",
        postal_code: "75001",
        street_name: "Rue de Rivoli",
        street_number: "10"
      }
    },
    %Company{
      id: 2,
      name: "Globex Corp",
      email: "ap@globex.test",
      phone_number: "+1 555 0199",
      vat_number: "VAT777",
      registration_number: "REG111",
      solvency_status: "at_risk",
      invoices_count: 0,
      payment_methods_count: 0,
      customer_projects: [],
      address: %{city: "Berlin", country: "DE", postal_code: "10115"}
    }
  ]

  @invoices [
    %Invoice{
      id: 1001,
      type: "subscription",
      status: "paid",
      cycle: 3,
      beginning: "2026-05-01",
      end: "2026-05-31",
      decimal_places: 2,
      amount_before_tax: 10_000,
      tax_amount: 2_000,
      amount_with_tax: 12_000,
      breakdown: []
    },
    %Invoice{
      id: 1002,
      type: "onetime",
      status: "pending",
      cycle: 4,
      beginning: "2026-06-01",
      end: "2026-06-30",
      decimal_places: 2,
      amount_before_tax: 4_500,
      tax_amount: 900,
      amount_with_tax: 5_400,
      breakdown: []
    }
  ]

  @payment_methods [
    %{
      id: 5,
      type: "stripe_card",
      status: "active",
      default_payment_method: true,
      stripe_card: %{brand: "visa", last4: "4242", exp_month: 12, exp_year: 2030}
    }
  ]

  @impl true
  def get_companies(_token, _opts),
    do: {:ok, %{companies: @companies, total: length(@companies), count: length(@companies)}}

  @impl true
  def get_company(_token, id) do
    id = to_int(id)

    case Enum.find(@companies, &(&1.id == id)) do
      nil -> {:error, "company not found"}
      company -> {:ok, company}
    end
  end

  @impl true
  def create_company(_token, input),
    do: {:ok, struct(Company, Map.put(input_to_company(input), :id, 99))}

  @impl true
  def update_company(_token, id, input),
    do: {:ok, struct(Company, Map.put(input_to_company(input), :id, to_int(id)))}

  @impl true
  def delete_company(_token, _id), do: {:ok, "Company deleted"}

  @impl true
  def get_unlinked_projects(_token, _project_ids), do: {:ok, ["proj-unlinked-1", "proj-unlinked-2"]}

  @impl true
  def link_projects(token, id, _project_ids), do: get_company(token, id)

  @impl true
  def unlink_project(token, id, _project_id), do: get_company(token, id)

  @impl true
  def get_invoices(_token, _opts),
    do: {:ok, %{invoices: @invoices, total: length(@invoices), count: length(@invoices)}}

  @impl true
  def get_invoice(_token, id) do
    id = to_int(id)

    case Enum.find(@invoices, &(&1.id == id)) do
      nil -> {:error, "invoice not found"}
      invoice -> {:ok, invoice}
    end
  end

  @impl true
  def get_payment_methods(_token, _opts),
    do:
      {:ok,
       %{
         payment_methods: @payment_methods,
         total: length(@payment_methods),
         count: length(@payment_methods)
       }}

  # Stripe's card Element only mounts with a *valid* publishable key, so the dev
  # harness uses Stripe's public documentation test key — this lets the "Add a
  # card" field actually render locally. The `client_secret` is still a stub, so
  # clicking "Save card" won't complete a real SetupIntent (that needs a real
  # Beelee/Stripe backend); it only exercises the modal + Elements mounting.
  @impl true
  def request_setup_intent(_token, _company_id),
    do:
      {:ok,
       %{
         client_secret: "seti_demo_secret",
         publishable_key: "pk_test_TYooMQauvdEDq54NiTphI7jx",
         verified: true
       }}

  @impl true
  def deactivate_payment_method(_token, _id), do: {:ok, "deactivated"}

  @impl true
  def reactivate_payment_method(_token, _id), do: {:ok, "active"}

  @impl true
  def make_default_payment_method(_token, _company_id, _payment_id), do: {:ok, "stripe_card"}

  defp input_to_company(input) do
    %{
      name: input[:name],
      email: input[:email],
      phone_number: input[:phoneNumber],
      vat_number: input[:vatNumber],
      registration_number: input[:registrationNumber],
      address: input[:address] || %{},
      customer_projects: []
    }
  end

  defp to_int(id) when is_integer(id), do: id
  defp to_int(id) when is_binary(id), do: String.to_integer(id)
end
