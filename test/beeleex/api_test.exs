defmodule BeeleexApiTest do
  use ExUnit.Case, async: false

  defmodule MockBeeleeApi do
    use Plug.Router

    import Plug.Conn

    plug(:match)
    plug(:dispatch)

    post "/v0-1/api" do
      {:ok, body, conn} = read_body(conn)
      payload = Poison.decode!(body)

      receiver = Application.get_env(:beeleex, :beeleex_api_test_receiver)
      response_fun = Application.get_env(:beeleex, :beeleex_api_test_response_fun)

      if receiver, do: send(receiver, {:beeleex_api_request, payload, conn.req_headers})

      response =
        if is_function(response_fun) do
          response_fun.(payload)
        else
          %{"data" => %{"" => %{}}}
        end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Poison.encode!(response))
    end

    match _ do
      send_resp(conn, 404, "{}")
    end

    def init(opts), do: opts
  end

  setup_all do
    port = free_port()
    old_endpoint = Application.get_env(:beeleex, :beelee_endpoint)

    {:ok, pid} = Plug.Cowboy.http(MockBeeleeApi, [], port: port)
    Application.put_env(:beeleex, :beelee_endpoint, "http://127.0.0.1:#{port}/v0-1/api")

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :normal)

      if is_nil(old_endpoint) do
        Application.delete_env(:beeleex, :beelee_endpoint)
      else
        Application.put_env(:beeleex, :beelee_endpoint, old_endpoint)
      end

      Application.delete_env(:beeleex, :beeleex_api_test_receiver)
      Application.delete_env(:beeleex, :beeleex_api_test_response_fun)
    end)

    :ok
  end

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  defp with_mocked_beelee_api(response_fun, fun) do
    old_receiver = Application.get_env(:beeleex, :beeleex_api_test_receiver)
    old_response_fun = Application.get_env(:beeleex, :beeleex_api_test_response_fun)

    Application.put_env(:beeleex, :beeleex_api_test_receiver, self())
    Application.put_env(:beeleex, :beeleex_api_test_response_fun, response_fun)

    try do
      fun.()
    after
      if old_receiver == nil do
        Application.delete_env(:beeleex, :beeleex_api_test_receiver)
      else
        Application.put_env(:beeleex, :beeleex_api_test_receiver, old_receiver)
      end

      if old_response_fun == nil do
        Application.delete_env(:beeleex, :beeleex_api_test_response_fun)
      else
        Application.put_env(:beeleex, :beeleex_api_test_response_fun, old_response_fun)
      end
    end
  end

  defp assert_request do
    receive do
      {:beeleex_api_request, payload, _headers} -> payload
    after
      1_000 -> flunk("did not capture API request")
    end
  end

  defp assert_request_with_headers do
    receive do
      {:beeleex_api_request, payload, headers} -> {payload, headers}
    after
      1_000 -> flunk("did not capture API request")
    end
  end

  defp with_authenticated_business_unit(fun) do
    old_secure_key = Application.get_env(:beeleex, :business_unit_secure_key)
    old_bu_id = Application.get_env(:beeleex, :business_unit_id)

    Application.put_env(:beeleex, :business_unit_secure_key, "test-secure-key")
    Application.put_env(:beeleex, :business_unit_id, 123)

    try do
      fun.()
    after
      if old_secure_key == nil do
        Application.delete_env(:beeleex, :business_unit_secure_key)
      else
        Application.put_env(:beeleex, :business_unit_secure_key, old_secure_key)
      end

      if old_bu_id == nil do
        Application.delete_env(:beeleex, :business_unit_id)
      else
        Application.put_env(:beeleex, :business_unit_id, old_bu_id)
      end
    end
  end

  defp business_unit_response do
    %{
      "archived" => false,
      "billingCenter" => %{"id" => 4, "name" => "Billing", "vatNumber" => "BE123"},
      "cycle" => "monthly",
      "devMode" => true,
      "id" => 42,
      "invoicesCount" => 7,
      "job" => %{"scheduledAt" => "2026-09-01T00:00:00Z"},
      "name" => "Updated BU",
      "secureKey" => "returned-secure-key",
      "startCycleDate" => "2026-08-01",
      "tokenValidationUrl" => "https://example.test/verify_token",
      "verifyCardAttachment" => true,
      "webhookUrl" => "https://example.test/webhooks/beelee"
    }
  end

  test "get_business_unit sends secure headers and returns a BusinessUnit" do
    with_authenticated_business_unit(fn ->
      with_mocked_beelee_api(
        fn _payload ->
          %{"data" => %{"getBusinessUnit" => business_unit_response()}}
        end,
        fn ->
          assert {:ok, business_unit} = Beeleex.Api.get_business_unit("42")
          assert %Beeleex.BusinessUnit{} = business_unit
          assert business_unit.id == 42
          assert business_unit.name == "Updated BU"
          assert business_unit.secure_key == "returned-secure-key"
          assert business_unit.verify_card_attachment == true
          assert business_unit.billing_center == %{id: 4, name: "Billing", vat_number: "BE123"}
          assert business_unit.job == %{scheduled_at: "2026-09-01T00:00:00Z"}

          {request, headers} = assert_request_with_headers()
          headers = Map.new(headers)

          assert request["query"] =~ "query getBusinessUnit"
          assert request["query"] =~ "$id: Int!"
          assert request["query"] =~ "getBusinessUnit(id: $id)"
          assert request["variables"]["id"] == 42
          assert headers["secure-key"] == "test-secure-key"
          assert headers["bu-id"] == "123"
        end
      )
    end)
  end

  test "get_business_unit returns GraphQL errors" do
    with_authenticated_business_unit(fn ->
      with_mocked_beelee_api(
        fn _payload ->
          %{"data" => %{"getBusinessUnit" => nil}, "errors" => [%{"message" => "not found"}]}
        end,
        fn ->
          assert {:error, "not found"} = Beeleex.Api.get_business_unit(42)
          _request = assert_request()
        end
      )
    end)
  end

  test "edit_business_unit sends secure headers and returns a BusinessUnit" do
    business_unit_input = %{
      cycle: "monthly",
      name: "Updated BU",
      startCycleDate: "2026-08-01",
      tokenValidationUrl: "https://example.test/verify_token",
      verifyCardAttachment: true,
      webhookUrl: "https://example.test/webhooks/beelee"
    }

    with_authenticated_business_unit(fn ->
      with_mocked_beelee_api(
        fn _payload ->
          %{"data" => %{"editBusinessUnit" => business_unit_response()}}
        end,
        fn ->
          assert {:ok, business_unit} = Beeleex.Api.edit_business_unit("42", business_unit_input)
          assert %Beeleex.BusinessUnit{} = business_unit
          assert business_unit.id == 42
          assert business_unit.name == "Updated BU"
          assert business_unit.secure_key == "returned-secure-key"
          assert business_unit.verify_card_attachment == true
          assert business_unit.billing_center == %{id: 4, name: "Billing", vat_number: "BE123"}
          assert business_unit.job == %{scheduled_at: "2026-09-01T00:00:00Z"}

          {request, headers} = assert_request_with_headers()
          headers = Map.new(headers)

          assert request["query"] =~ "mutation editBusinessUnit"
          assert request["query"] =~ "$businessUnit: BusinessUnitInput!"
          assert request["query"] =~ "editBusinessUnit(businessUnit: $businessUnit, id: $id)"

          assert request["variables"]["businessUnit"] ==
                   Poison.decode!(Poison.encode!(business_unit_input))

          assert request["variables"]["id"] == 42
          assert headers["secure-key"] == "test-secure-key"
          assert headers["bu-id"] == "123"
        end
      )
    end)
  end

  test "edit_business_unit returns GraphQL errors" do
    with_authenticated_business_unit(fn ->
      with_mocked_beelee_api(
        fn _payload ->
          %{"data" => %{"editBusinessUnit" => nil}, "errors" => [%{"message" => "forbidden"}]}
        end,
        fn ->
          assert {:error, "forbidden"} = Beeleex.Api.edit_business_unit(42, %{})
          _request = assert_request()
        end
      )
    end)
  end

  test "run_next_scheduled_business_unit_cycle sends secure headers and returns a BusinessUnit" do
    with_authenticated_business_unit(fn ->
      with_mocked_beelee_api(
        fn _payload ->
          %{"data" => %{"runNextScheduledBusinessUnitCycle" => business_unit_response()}}
        end,
        fn ->
          assert {:ok, business_unit} =
                   Beeleex.Api.run_next_scheduled_business_unit_cycle("42")

          assert %Beeleex.BusinessUnit{} = business_unit
          assert business_unit.id == 42
          assert business_unit.name == "Updated BU"
          assert business_unit.secure_key == "returned-secure-key"
          assert business_unit.verify_card_attachment == true
          assert business_unit.billing_center == %{id: 4, name: "Billing", vat_number: "BE123"}
          assert business_unit.job == %{scheduled_at: "2026-09-01T00:00:00Z"}

          {request, headers} = assert_request_with_headers()
          headers = Map.new(headers)

          assert request["query"] =~ "mutation runNextScheduledBusinessUnitCycle"
          assert request["query"] =~ "$id: Int!"
          assert request["query"] =~ "runNextScheduledBusinessUnitCycle(id: $id)"
          assert request["variables"]["id"] == 42
          assert headers["secure-key"] == "test-secure-key"
          assert headers["bu-id"] == "123"
        end
      )
    end)
  end

  test "run_next_scheduled_business_unit_cycle returns GraphQL errors" do
    with_authenticated_business_unit(fn ->
      with_mocked_beelee_api(
        fn _payload ->
          %{
            "data" => %{"runNextScheduledBusinessUnitCycle" => nil},
            "errors" => [%{"message" => "cycle unavailable"}]
          }
        end,
        fn ->
          assert {:error, "cycle unavailable"} =
                   Beeleex.Api.run_next_scheduled_business_unit_cycle(42)

          _request = assert_request()
        end
      )
    end)
  end

  defp invoice_tag_fixtures do
    checkout_tags = ["checkout_operation:16a11704-d76f-4cce-8d61-c07865afe2ee", "Source:Portal"]
    cycle_tags = ["project:acme", "billing:monthly"]
    batched_tags = ["project:acme", "payment:batched"]

    [
      {%{"id" => 1, "type" => "one_time", "tags" => checkout_tags}, checkout_tags},
      {%{"id" => 2, "type" => "cycle", "tags" => cycle_tags}, cycle_tags},
      # Batch membership does not replace the invoice's underlying type.
      {%{"id" => 3, "type" => "cycle", "paymentBatchId" => 4, "tags" => batched_tags},
       batched_tags},
      {%{"id" => 4, "type" => "cycle", "tags" => []}, []},
      {%{"id" => 5, "type" => "one_time"}, nil},
      {%{"id" => 6, "type" => "cycle", "tags" => nil}, nil}
    ]
  end

  defp accounting_invoice do
    %{
      "id" => 42,
      "invoiceNumber" => "9223372036854775807",
      "invoiceReference" => "BU-2026-11-42",
      "currency" => "USD",
      "decimalPlaces" => 2,
      "amountBeforeTax" => 9_223_372_036_854_775_000,
      "taxAmount" => 807,
      "taxRate" => 2000,
      "amountWithTax" => 9_223_372_036_854_775_807,
      "reductionAmountBeforeTax" => 1000,
      "reductionTaxAmount" => 200,
      "reductionAmountWithTax" => 1200,
      "outstandingAmount" => "9223372036854774607",
      "issuedAt" => "2026-11-27T10:20:30Z",
      "taxPointDate" => "2026-11-26",
      "dueDate" => "2026-11-27",
      "closingDate" => nil,
      "accountingDataStatus" => "COMPLETE",
      "sellerCurrency" => "EUR",
      "sellerDecimalPlaces" => 3,
      "exchangeRate" => "0.092000000000000001",
      "sellerAmountBeforeTax" => "8485502273906393000",
      "sellerTaxAmount" => "742",
      "sellerAmountWithTax" => "8485502273906393742",
      "sellerSnapshot" => %{
        "sourceId" => 7,
        "name" => "Original Seller",
        "vatNumber" => "VAT-7",
        "registrationNumber" => "REG-7",
        "address" => %{
          "streetNumber" => "10",
          "streetName" => "Original Street",
          "postalCode" => "75001",
          "city" => "Paris",
          "country" => "FR"
        }
      },
      "buyerSnapshot" => %{"sourceId" => 1, "name" => "Original Buyer", "address" => nil},
      "company" => %{"id" => 1, "name" => "Live renamed company"},
      "breakdown" => [
        %{
          "projectId" => "project-1",
          "projectName" => "Project One",
          "packageName" => "Package One",
          "packageDescription" => "Stored package",
          "packagePriceBeforeTax" => 1000,
          "packageTax" => 200,
          "packageTaxRate" => 2000,
          "packagePriceWithTax" => 1200,
          "payAsYouGo" => [
            %{
              "name" => "Requests",
              "description" => "Stored usage",
              "quantity" => 3,
              "unitPriceBeforeTax" => 100,
              "totalBeforeTax" => 300,
              "tax" => 30,
              "taxRate" => 1000,
              "totalWithTax" => 330
            }
          ]
        }
      ]
    }
  end

  test "all invoice entry points request and retain exact accounting and nested line facts" do
    raw = accounting_invoice()

    with_mocked_beelee_api(
      fn _payload ->
        %{
          "data" => %{
            "getInvoice" => raw,
            "getInvoices" => %{"invoices" => [raw], "total" => 1, "count" => 1},
            "generateOnetimeInvoice" => raw
          }
        }
      end,
      fn ->
        assert {:ok, detail} = Beeleex.Api.get_invoice("token", "42")
        assert_accounting_request(raw, assert_request()["query"])
        assert {:ok, %{invoices: [^detail]}} = Beeleex.Api.get_invoices("token")
        assert_accounting_request(raw, assert_request()["query"])

        assert {:ok, [^detail]} =
                 Beeleex.Api.get_current_cycle_invoices("1", "project-1", "cycle")

        cycle_request = assert_request()
        assert_accounting_request(raw, cycle_request["query"])
        assert cycle_request["variables"]["currentCycle"] == true
        assert cycle_request["query"] =~ "currentCycle: $currentCycle"

        assert {:ok, ^detail} =
                 Beeleex.Api.generate_onetime_invoice(%Beeleex.OnetimePayment{
                   companyId: 1,
                   pricing: []
                 })

        assert_accounting_request(raw, assert_request()["query"])
        assert detail.invoice_number == "9223372036854775807"
        assert detail.invoice_reference == "BU-2026-11-42"
        assert detail.amount_with_tax == 9_223_372_036_854_775_807
        assert detail.outstanding_amount == "9223372036854774607"
        assert detail.exchange_rate == "0.092000000000000001"
        assert detail.seller_amount_with_tax == "8485502273906393742"
        assert detail.seller_decimal_places == 3
        assert detail.currency == "USD"
        assert detail.seller_currency == "EUR"
        assert detail.seller_snapshot.address.street_name == "Original Street"
        assert detail.seller_snapshot.registration_number == "REG-7"
        assert detail.buyer_snapshot.name == "Original Buyer"
        assert %Beeleex.Company{id: 1, name: "Live renamed company"} = detail.company
        assert detail.issued_at == "2026-11-27T10:20:30Z"
        assert detail.tax_point_date == "2026-11-26"
        assert detail.due_date == "2026-11-27"
        assert detail.closing_date == nil
        assert detail.reduction_amount_with_tax == 1200
        assert detail.accounting_data_status == "COMPLETE"
        [package] = detail.breakdown
        assert package.package_description == "Stored package"
        assert package.package_tax_rate == 2000
        assert package.package_price_with_tax == 1200
        assert [usage] = package.pay_as_you_go
        assert usage.quantity == 3
        assert usage.unit_price_before_tax == 100
        assert usage.total_before_tax == 300
        assert usage.tax_rate == 1000
        assert usage.tax == 30
        assert usage.total_with_tax == 330
      end
    )
  end

  # The HTTP fixture cannot validate GraphQL, so require every fixture field to
  # appear in the request too, including nested snapshots and line-item fields.
  defp assert_accounting_request(value, query) when is_map(value) do
    for {field, nested} <- value do
      assert query =~ ~r/\b#{field}\b/
      assert_accounting_request(nested, query)
    end
  end

  defp assert_accounting_request(values, query) when is_list(values),
    do: Enum.each(values, &assert_accounting_request(&1, query))

  defp assert_accounting_request(_value, _query), do: :ok

  test "decodes draft, unnumbered, paid and partial historical nulls without inferred facts" do
    for status <- ["DRAFT", "COMPLETE", "LEGACY_PARTIAL"],
        balance <- [nil, "0"] do
      raw = %{
        "id" => 42,
        "accountingDataStatus" => status,
        "invoiceNumber" => nil,
        "invoiceReference" => nil,
        "issuedAt" => nil,
        "sellerSnapshot" => nil,
        "buyerSnapshot" => nil,
        "currency" => nil,
        "sellerCurrency" => nil,
        "exchangeRate" => nil,
        "outstandingAmount" => balance,
        "company" => nil
      }

      with_mocked_beelee_api(
        fn _payload -> %{"data" => %{"getInvoice" => raw}} end,
        fn ->
          assert {:ok, invoice} = Beeleex.Api.get_invoice("token", 42)
          assert invoice.accounting_data_status == status
          assert invoice.outstanding_amount == balance
          assert invoice.company == nil

          for field <-
                ~w(invoice_number invoice_reference issued_at seller_snapshot buyer_snapshot currency seller_currency exchange_rate amount_with_tax decimal_places)a do
            assert Map.fetch!(invoice, field) == nil
          end

          assert_request()
        end
      )
    end
  end

  test "get_invoice selects and decodes original invoice tags" do
    fixtures = invoice_tag_fixtures()
    invoices = Map.new(fixtures, fn {invoice, _tags} -> {invoice["id"], invoice} end)

    with_mocked_beelee_api(
      fn %{"variables" => %{"id" => id}} ->
        %{"data" => %{"getInvoice" => Map.fetch!(invoices, id)}}
      end,
      fn ->
        for {%{"id" => id, "type" => type}, expected_tags} <- fixtures do
          assert {:ok, %Beeleex.Invoice{id: ^id, type: ^type, tags: ^expected_tags, company: nil}} =
                   Beeleex.Api.get_invoice("token", to_string(id))

          assert {request, headers} = assert_request_with_headers()
          assert request["query"] =~ ~r/getInvoice\([^)]*\)\s*\{[^{}]*\btags\b/
          assert request["variables"] == %{"id" => id}
          assert {"bu-authorization", "Bearer token"} in headers
        end
      end
    )
  end

  test "get_invoices selects and decodes tags for each invoice in the page" do
    fixtures = invoice_tag_fixtures()
    invoices = Enum.map(fixtures, &elem(&1, 0))

    with_mocked_beelee_api(
      fn _payload ->
        %{"data" => %{"getInvoices" => %{"invoices" => invoices, "total" => 10, "count" => 6}}}
      end,
      fn ->
        assert {:ok, %{invoices: decoded, total: 10, count: 6}} =
                 Beeleex.Api.get_invoices("token")

        assert Enum.map(decoded, fn %Beeleex.Invoice{id: id, type: type, tags: tags} ->
                 {id, type, tags}
               end) ==
                 Enum.map(fixtures, fn {%{"id" => id, "type" => type}, tags} ->
                   {id, type, tags}
                 end)

        assert assert_request()["query"] =~ ~r/\binvoices\s*\{[^{}]*\btags\b/
      end
    )
  end

  test "get_current_cycle_invoices retains all tags, not just the filter tag" do
    tags = ["project:acme", "Source:Portal"]
    invoice = %{"id" => 2, "type" => "cycle", "tags" => tags}

    with_mocked_beelee_api(
      fn _payload ->
        %{"data" => %{"getInvoices" => %{"invoices" => [invoice], "count" => 1}}}
      end,
      fn ->
        assert {:ok, [%Beeleex.Invoice{id: 2, tags: ^tags}]} =
                 Beeleex.Api.get_current_cycle_invoices("1", "acme", "project:acme")

        request = assert_request()
        assert request["query"] =~ ~r/\binvoices\s*\{[^{}]*\btags\b/
        assert %{"key" => "tag", "value" => "project:acme"} in request["variables"]["filter"]
      end
    )
  end

  test "generate_onetime_invoice sends input tags and returns Beelee's tags" do
    input_tags = ["checkout_operation:16a11704-d76f-4cce-8d61-c07865afe2ee"]
    returned_tags = input_tags ++ ["Source:Beelee"]

    payment = %Beeleex.OnetimePayment{
      companyId: 1,
      decimalPlaces: 2,
      pricing: [],
      tags: input_tags
    }

    invoice = %{"id" => 1, "type" => "one_time", "tags" => returned_tags}

    with_mocked_beelee_api(
      fn _payload -> %{"data" => %{"generateOnetimeInvoice" => invoice}} end,
      fn ->
        assert {:ok, %Beeleex.Invoice{id: 1, tags: ^returned_tags}} =
                 Beeleex.Api.generate_onetime_invoice(payment)

        request = assert_request()
        assert request["query"] =~ ~r/generateOnetimeInvoice\([^)]*\)\s*\{[^{}]*\btags\b/
        assert request["variables"]["onetimeInvoice"]["tags"] == input_tags
      end
    )
  end

  test "update_invoices still sends tags in the invoice input" do
    tags = ["billing:monthly", "Source:Portal"]

    invoice = %Beeleex.InvoiceUpdate{
      cycle: %{id: 42},
      tags: tags
    }

    with_mocked_beelee_api(
      fn _payload -> %{"data" => %{"updateCompanyInvoices" => %{"message" => "updated"}}} end,
      fn ->
        assert {:ok, "updated"} = Beeleex.Api.update_invoices([invoice])
        assert [%{"tags" => ^tags} = payload] = assert_request()["variables"]["companyInvoices"]
        refute Map.has_key?(payload, "currency")
        refute Map.has_key?(payload, "exchangeRate")
        refute Map.has_key?(payload, "taxPointDate")
      end
    )
  end

  test "update_invoices sends exact FX and preserves the request-level error" do
    invoice = %Beeleex.InvoiceUpdate{
      companyId: 5,
      cycle: %{id: 42},
      currency: "GBP",
      exchangeRate: "0.920000000000000001",
      taxPointDate: ~D[2026-11-25],
      pricing: [],
      decimalPlaces: 2
    }

    message = "exchangeRate is required: provide EUR per 1 GBP."

    with_mocked_beelee_api(
      fn _ ->
        %{"data" => %{"updateCompanyInvoices" => nil}, "errors" => [%{"message" => message}]}
      end,
      fn ->
        assert {:error, ^message} =
                 Beeleex.Api.update_invoices([
                   invoice,
                   %{invoice | companyId: 6, exchangeRate: nil}
                 ])

        request = assert_request()
        assert request["query"] =~ "updateCompanyInvoices"

        assert [
                 %{
                   "currency" => "GBP",
                   "exchangeRate" => "0.920000000000000001",
                   "taxPointDate" => "2026-11-25",
                   "cycleId" => 42
                 },
                 %{"companyId" => 6} = without_rate
               ] = request["variables"]["companyInvoices"]

        refute Map.has_key?(without_rate, "exchangeRate")
      end
    )
  end

  test "one-time pricing passes optional accounting fields and returns FX errors" do
    payment = %Beeleex.OnetimePayment{
      companyId: 1,
      currency: "GBP",
      exchangeRate: "1.200000000000000001",
      taxPointDate: ~D[2026-11-25]
    }

    message = "exchangeRate is required: provide EUR per 1 GBP."

    with_mocked_beelee_api(
      fn _ ->
        %{"data" => %{"generateOnetimeInvoice" => nil}, "errors" => [%{"message" => message}]}
      end,
      fn ->
        assert {:error, ^message} = Beeleex.Api.generate_onetime_invoice(payment)

        assert %{
                 "currency" => "GBP",
                 "exchangeRate" => "1.200000000000000001",
                 "taxPointDate" => "2026-11-25"
               } = assert_request()["variables"]["onetimeInvoice"]
      end
    )
  end

  test "credit-note APIs select originating invoice tags separately from credit-note tags" do
    invoice_tags = ["project:acme", "Source:Portal"]
    note_tags = ["credit:adjustment"]
    invoice = %{"id" => 2, "tags" => invoice_tags}
    note = %{"id" => 1, "tags" => note_tags}

    with_mocked_beelee_api(
      fn %{"query" => query} ->
        camel_note = Map.put(note, "originatingInvoice", invoice)
        snake_note = Map.put(note, "originating_invoice", invoice)

        data =
          case query do
            "mutation createCreditNote(" <> _ ->
              %{"createCreditNote" => camel_note}

            "query getCreditNotes(" <> _ ->
              %{"getCreditNotes" => %{"data" => [snake_note]}}

            "mutation requestCredit(" <> _ ->
              %{"requestCreditForCycle" => %{"creditNotes" => [snake_note], "remainder" => 0}}
          end

        %{"data" => data}
      end,
      fn ->
        assert {:ok, %Beeleex.CreditNote{tags: ^note_tags, originating_invoice: origin}} =
                 Beeleex.Api.generate_credit_note(100, 2, "adjustment", note_tags)

        assert origin == %{id: 2, tags: invoice_tags}
        assert assert_request()["query"] =~ ~r/\boriginatingInvoice\s*\{[^{}]*\btags\b/

        assert {:ok, [%Beeleex.CreditNote{tags: ^note_tags, originating_invoice: ^origin}]} =
                 Beeleex.Api.get_credit_notes_for_invoices("1", [%Beeleex.Invoice{id: 2}])

        assert assert_request()["query"] =~ ~r/\boriginating_invoice\s*\{[^{}]*\btags\b/

        assert {:ok, [%Beeleex.CreditNote{tags: ^note_tags, originating_invoice: ^origin}], 0} =
                 Beeleex.Api.request_credit_in_cycle(
                   "1",
                   100,
                   "project:acme",
                   "adjustment",
                   note_tags
                 )

        assert assert_request()["query"] =~ ~r/\boriginating_invoice\s*\{[^{}]*\btags\b/
      end
    )
  end

  test "make_default uses paymentMethodId variable" do
    with_mocked_beelee_api(
      fn _payload ->
        %{"data" => %{"changeDefaultPaymentMethod" => %{"type" => "stripe_card"}}}
      end,
      fn ->
        assert {:ok, "stripe_card"} =
                 Beeleex.Api.make_default_payment_method("token", "1", "42")

        request = assert_request()

        assert request["query"] =~ "$companyId:Int!"
        assert request["query"] =~ "$paymentMethodId:Int!"
        assert request["query"] =~ "changeDefaultPaymentMethod"
        assert request["variables"]["companyId"] == 1
        assert request["variables"]["paymentMethodId"] == 42
        refute Map.has_key?(request["variables"], "paymentId")
      end
    )
  end

  test "deactivate_payment_method uses ID variable" do
    with_mocked_beelee_api(
      fn _payload ->
        %{"data" => %{"deactivatePaymentMethod" => %{"status" => "inactive"}}}
      end,
      fn ->
        assert {:ok, "inactive"} = Beeleex.Api.deactivate_payment_method("token", "7")

        request = assert_request()

        assert request["query"] =~ "$id: Int!"
        assert request["variables"]["id"] == 7
      end
    )
  end

  test "reactivate_payment_method uses ID variable" do
    with_mocked_beelee_api(
      fn _payload ->
        %{"data" => %{"retryPaymentMethod" => %{"status" => "active"}}}
      end,
      fn ->
        assert {:ok, "active"} = Beeleex.Api.reactivate_payment_method("token", 99)

        request = assert_request()

        assert request["query"] =~ "$id: Int!"
        assert request["variables"]["id"] == 99
      end
    )
  end
end
