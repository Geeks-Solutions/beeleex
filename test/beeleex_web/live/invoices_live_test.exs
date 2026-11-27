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
        invoice_number: "42",
        invoice_reference: "BU-2026-11-42",
        accounting_data_status: "COMPLETE",
        type: "subscription",
        status: "paid",
        currency: "USD",
        issued_at: "2026-11-27T10:20:30Z",
        tax_point_date: "2026-11-26",
        due_date: "2026-11-27",
        closing_date: "2026-11-28T09:00:00Z",
        inserted_at: "2026-11-01T00:00:00Z",
        cycle: 3,
        beginning: "2026-01-01",
        end: "2026-01-31",
        decimal_places: 2,
        amount_before_tax: 1000,
        tax_amount: 200,
        tax_rate: 2000,
        amount_with_tax: 1200,
        reduction_amount_before_tax: 100,
        reduction_tax_amount: 20,
        reduction_amount_with_tax: 120,
        outstanding_amount: "0",
        seller_currency: "EUR",
        seller_decimal_places: 2,
        exchange_rate: "0.920000000000000001",
        seller_amount_before_tax: "920",
        seller_tax_amount: "184",
        seller_amount_with_tax: "1104",
        seller_snapshot: %{
          source_id: 7,
          name: "Seller at issuance",
          vat_number: "FR-VAT-7",
          registration_number: "SELLER-REG",
          address: %{
            street_number: "10",
            street_name: "Original Street",
            postal_code: "75001",
            city: "Paris",
            country: "FR"
          }
        },
        buyer_snapshot: %{
          source_id: 1,
          name: "Buyer at issuance",
          vat_number: "BUYER-VAT",
          registration_number: "BUYER-REG",
          address: nil
        },
        company: %{id: 1, name: "Live renamed buyer"},
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
      assert html =~ "BU-2026-11-42"
      assert html =~ "Internal ID: 42"
      assert html =~ "12.00 USD"
      assert html =~ "1.20 USD"
      assert html =~ "0.00 USD"
      assert html =~ "2026-11-27T10:20:30Z"
      assert html =~ "2026-11-27"
      assert html =~ "Paid"
      assert html =~ "Complete accounting"
    end

    test "distinguishes drafts, unnumbered and partial history with large exact balances", %{
      conn: conn
    } do
      stub(Beeleex.ApiMock, :get_company, fn _token, "1" -> {:ok, company()} end)

      invoices = [
        invoice(%{
          id: 1,
          invoice_number: nil,
          invoice_reference: nil,
          accounting_data_status: "DRAFT",
          status: "pending_host",
          issued_at: nil,
          due_date: nil,
          amount_with_tax: 0,
          reduction_amount_with_tax: 0,
          outstanding_amount: nil
        }),
        invoice(%{
          id: 2,
          invoice_number: nil,
          invoice_reference: nil,
          currency: "JPY",
          decimal_places: 0,
          amount_with_tax: "9223372036854775807",
          outstanding_amount: "9223372036854775687",
          status: "payment_failed"
        }),
        invoice(%{
          id: 3,
          accounting_data_status: "LEGACY_PARTIAL",
          currency: nil,
          issued_at: nil,
          due_date: nil
        })
      ]

      stub(Beeleex.ApiMock, :get_invoices, fn _, _ ->
        {:ok, %{invoices: invoices, total: 3, count: 3}}
      end)

      {:ok, view, _html} = live(conn, "/companies/1")
      rows = view |> element(".beeleex-invoices tbody") |> render() |> Floki.parse_fragment!()
      [draft, unnumbered, historical] = Floki.find(rows, "tr")
      assert Floki.text(draft) =~ "Draft invoice"
      assert Floki.text(draft) =~ "Awaiting pricing"
      assert Floki.text(draft) =~ "— USD"
      refute Floki.text(draft) =~ "0.00 USD"
      assert Floki.text(unnumbered) =~ "Unnumbered invoice"
      assert Floki.text(unnumbered) =~ "9223372036854775807 JPY"
      assert Floki.text(unnumbered) =~ "9223372036854775687 JPY"
      assert Floki.text(unnumbered) =~ "Payment failed"
      assert Floki.text(historical) =~ "Incomplete historical accounting"
      assert Floki.text(historical) =~ "12.00 currency unknown"
    end
  end

  describe "invoice detail" do
    test "renders a single invoice", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_invoice, fn _token, "42" -> {:ok, invoice()} end)

      {:ok, _view, html} = live(conn, "/companies/1/invoices/42")

      assert html =~ "Invoice BU-2026-11-42"
      refute html =~ "Invoice #42"
      assert html =~ "Internal ID"
      assert html =~ "10.00 USD"
      assert html =~ "12.00 USD"
      assert html =~ "1.20 USD"
      assert html =~ "0.00 USD"
      assert html =~ "2026-11-27T10:20:30Z"
      assert html =~ "2026-11-26"
      assert html =~ "2026-11-28T09:00:00Z"
      assert html =~ "2026-11-01T00:00:00Z"
      assert html =~ "Seller at issuance"
      assert html =~ "Buyer at issuance"
      assert html =~ "FR-VAT-7"
      assert html =~ "SELLER-REG"
      assert html =~ "BUYER-VAT"
      assert html =~ "BUYER-REG"
      assert html =~ "10, Original Street, 75001, Paris, FR"
      refute html =~ "Live renamed buyer"
      assert html =~ "1 USD = 0.920000000000000001 EUR"
      assert html =~ "9.20 EUR"
      assert html =~ "1.84 EUR"
      assert html =~ "11.04 EUR"
      assert html =~ "Back to company"
    end

    test "shows package and usage quantities, unit prices, mixed tax rates and totals", %{
      conn: conn
    } do
      invoice =
        invoice(%{
          currency: "KWD",
          decimal_places: 3,
          status: "payment_processing",
          outstanding_amount: "1080",
          breakdown: [
            %{
              project_id: "acme",
              project_name: "Acme project",
              package_name: "Base",
              package_description: "Stored package description",
              package_price_before_tax: 1000,
              package_tax: 200,
              package_tax_rate: 2000,
              package_price_with_tax: 1200,
              pay_as_you_go: [
                %{
                  name: "API calls",
                  description: "Stored usage description",
                  quantity: 3,
                  unit_price_before_tax: 101,
                  total_before_tax: 303,
                  tax: 30,
                  tax_rate: 1000,
                  total_with_tax: 333
                }
              ]
            }
          ]
        })

      stub(Beeleex.ApiMock, :get_invoice, fn _, _ -> {:ok, invoice} end)
      {:ok, view, html} = live(conn, "/companies/1/invoices/42")
      assert html =~ "1.080 KWD"
      assert html =~ "Payment processing"
      rows = view |> element("#invoice-breakdown tbody") |> render() |> Floki.parse_fragment!()
      [package, usage] = Floki.find(rows, "tr")
      package_cells = Enum.map(Floki.find(package, "td"), &Floki.text/1)
      usage_cells = Enum.map(Floki.find(usage, "td"), &Floki.text/1)
      assert Enum.at(package_cells, 1) =~ "Stored package description"
      assert Enum.at(usage_cells, 1) =~ "Stored usage description"

      assert Enum.map(Enum.slice(package_cells, 2, 6), &String.trim/1) ==
               ["1", "1.000 KWD", "1.000 KWD", "20.00%", "0.200 KWD", "1.200 KWD"]

      assert Enum.map(Enum.slice(usage_cells, 2, 6), &String.trim/1) ==
               ["3", "0.101 KWD", "0.303 KWD", "10.00%", "0.030 KWD", "0.333 KWD"]
    end

    test "does not invent historical parties, currency, issuance or balance", %{conn: conn} do
      partial =
        invoice(%{
          accounting_data_status: "LEGACY_PARTIAL",
          issued_at: nil,
          tax_point_date: nil,
          due_date: nil,
          seller_snapshot: nil,
          buyer_snapshot: nil,
          seller_currency: nil,
          seller_decimal_places: nil,
          exchange_rate: nil,
          seller_amount_before_tax: nil,
          seller_tax_amount: nil,
          seller_amount_with_tax: nil,
          currency: nil,
          outstanding_amount: nil,
          status: "payment_failed"
        })

      stub(Beeleex.ApiMock, :get_invoice, fn _, _ -> {:ok, partial} end)
      {:ok, view, html} = live(conn, "/companies/1/invoices/42")
      assert html =~ "Incomplete historical accounting"
      assert has_element?(view, "#invoice-seller", "Historical party snapshot not recorded")
      assert has_element?(view, "#invoice-buyer", "Historical party snapshot not recorded")
      assert has_element?(view, "#invoice-totals", "— currency unknown")
      refute html =~ "Live renamed buyer"
      refute has_element?(view, "#invoice-totals dd", ~r/^0\.00 currency unknown$/)
      refute html =~ "1 USD"
      refute html =~ " EUR"
      summary = view |> element(".bx-invoice-summary") |> render() |> Floki.parse_fragment!()

      assert Floki.find(summary, "dt") |> Enum.map(&Floki.text/1) |> Enum.take(6) ==
               [
                 "Official reference",
                 "Official number",
                 "Internal ID",
                 "Issued at (UTC)",
                 "Tax point date",
                 "Due date"
               ]

      assert Floki.find(summary, "dd") |> Enum.map(&Floki.text/1) |> Enum.take(6) ==
               ["BU-2026-11-42", "42", "42", "Not recorded", "Not recorded", "Not recorded"]
    end

    test "renders complete unnumbered issuance without assuming a reference",
         %{conn: conn} do
      unnumbered = invoice(%{invoice_number: nil, invoice_reference: nil})
      stub(Beeleex.ApiMock, :get_invoice, fn _, _ -> {:ok, unnumbered} end)
      {:ok, view, html} = live(conn, "/companies/1/invoices/42")
      assert has_element?(view, "h1", "Unnumbered invoice")
      assert html =~ "Complete accounting"
      assert html =~ "Buyer at issuance"
      assert html =~ "2026-11-27T10:20:30Z"
      refute html =~ "Draft invoice"
    end

    test "renders migration-frozen facts and recovered dates in list and detail", %{conn: conn} do
      migrated =
        invoice(%{
          invoice_reference: "HIST-2025-17",
          invoice_number: "17",
          issued_at: "2025-09-18T12:00:00Z",
          tax_point_date: "2025-09-18",
          due_date: "2025-09-18",
          currency: "EUR",
          decimal_places: 3,
          exchange_rate: "1",
          seller_decimal_places: 2,
          seller_amount_before_tax: "100",
          seller_tax_amount: "20",
          seller_amount_with_tax: "120",
          buyer_snapshot: %{
            source_id: 1,
            name: "Buyer frozen by migration",
            vat_number: "MIGRATED-VAT",
            registration_number: "MIGRATED-REG",
            address: %{city: "Historical city"}
          }
        })

      stub(Beeleex.ApiMock, :get_company, fn _, _ -> {:ok, company()} end)
      stub(Beeleex.ApiMock, :get_invoice, fn _, _ -> {:ok, migrated} end)

      stub(Beeleex.ApiMock, :get_invoices, fn _, _ ->
        {:ok, %{invoices: [migrated], total: 1, count: 1}}
      end)

      {:ok, _list, html} = live(conn, "/companies/1")
      assert html =~ "HIST-2025-17"
      assert html =~ "2025-09-18T12:00:00Z"
      assert html =~ "1.200 EUR"
      assert html =~ "0.120 EUR"
      assert html =~ "0.000 EUR"

      {:ok, detail, html} = live(conn, "/companies/1/invoices/42")
      assert has_element?(detail, "h1", "Invoice HIST-2025-17")
      assert has_element?(detail, "#invoice-buyer", "Buyer frozen by migration")
      assert has_element?(detail, "#invoice-buyer", "Historical city")
      assert has_element?(detail, "#invoice-totals", "1.200 EUR")
      assert has_element?(detail, "#invoice-reporting", "1.20 EUR")
      assert html =~ "1 EUR = 1 EUR"
      refute html =~ "Live renamed buyer"
    end

    test "renders a draft with null accounting and a partial invoice with an exact official number",
         %{conn: conn} do
      draft = %Beeleex.Invoice{
        id: 42,
        accounting_data_status: "DRAFT",
        status: "pending_host",
        currency: "EUR",
        decimal_places: 2,
        amount_before_tax: 0,
        tax_amount: 0,
        amount_with_tax: 0,
        reduction_amount_with_tax: 0
      }

      stub(Beeleex.ApiMock, :get_invoice, fn _, _ -> {:ok, draft} end)
      {:ok, view, html} = live(conn, "/companies/1/invoices/42")
      assert has_element?(view, "h1", "Draft invoice")
      assert html =~ "Draft — not issued"
      assert html =~ "— EUR"
      refute html =~ "0.00"

      numbered = %{
        draft
        | invoice_number: "9223372036854775807",
          accounting_data_status: "LEGACY_PARTIAL"
      }

      stub(Beeleex.ApiMock, :get_invoice, fn _, _ -> {:ok, numbered} end)
      {:ok, view, _html} = live(conn, "/companies/1/invoices/42")
      assert has_element?(view, "h1", "Invoice number 9223372036854775807")
    end

    test "renders large and negative monetary facts exactly at stored scales", %{conn: conn} do
      large =
        invoice(%{
          amount_with_tax: 9_223_372_036_854_775_807,
          outstanding_amount: "9223372036854775807",
          reduction_amount_with_tax: -1,
          seller_decimal_places: 3,
          seller_amount_with_tax: "-9223372036854775808"
        })

      stub(Beeleex.ApiMock, :get_invoice, fn _, _ -> {:ok, large} end)
      {:ok, view, _html} = live(conn, "/companies/1/invoices/42")
      assert has_element?(view, "#invoice-totals", "92233720368547758.07 USD")
      assert has_element?(view, "#invoice-totals", "-0.01 USD")
      assert has_element?(view, "#invoice-reporting", "-9223372036854775.808 EUR")
    end

    test "redirects to the company when the invoice is missing", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_invoice, fn _token, "99" -> {:error, "not found"} end)

      assert {:error, {:live_redirect, %{to: "/companies/1"}}} =
               live(conn, "/companies/1/invoices/99")
    end
  end
end
