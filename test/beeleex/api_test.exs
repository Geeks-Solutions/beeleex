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
