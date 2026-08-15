defmodule BeeleexWeb.InvoicesLiveTest do
  use BeeleexWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  # The company show page also embeds the payment-methods component.
  setup do
    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _ ->
      {:ok, %{payment_methods: [], total: 0, count: 0}}
    end)

    :ok
  end

  defp company(attrs \\ %{}) do
    Map.merge(
      %Beeleex.Company{id: 1, name: "Acme Inc", customer_projects: [], address: %{}},
      attrs
    )
  end

  defp invoice(attrs \\ %{}) do
    Map.merge(
      %Beeleex.Invoice{
        id: 42,
        type: "subscription",
        status: "paid",
        cycle: 3,
        beginning: "2026-01-01",
        end: "2026-01-31",
        decimal_places: 2,
        amount_before_tax: 1000,
        tax_amount: 200,
        amount_with_tax: 1200,
        breakdown: []
      },
      attrs
    )
  end

  describe "embedded invoices list (company show)" do
    test "lists the company's invoices", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_company, fn _token, "1" -> {:ok, company()} end)

      stub(Beeleex.ApiMock, :get_invoices, fn _token, opts ->
        assert [%{key: "company_id", value: "1"}] = Keyword.fetch!(opts, :filter)
        {:ok, %{invoices: [invoice()], total: 1, count: 1}}
      end)

      {:ok, _view, html} = live(conn, "/companies/1")

      assert html =~ "subscription"
      assert html =~ "12.00"
    end
  end

  describe "invoice detail" do
    test "renders a single invoice", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_invoice, fn _token, "42" -> {:ok, invoice()} end)

      {:ok, _view, html} = live(conn, "/companies/1/invoices/42")

      assert html =~ "Invoice #42"
      assert html =~ "10.00"
      assert html =~ "12.00"
      assert html =~ "Back to company"
    end

    test "redirects to the company when the invoice is missing", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_invoice, fn _token, "99" -> {:error, "not found"} end)

      assert {:error, {:live_redirect, %{to: "/companies/1"}}} =
               live(conn, "/companies/1/invoices/99")
    end
  end
end
