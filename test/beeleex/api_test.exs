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

      if receiver, do: send(receiver, {:beeleex_api_request, payload})

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
      {:beeleex_api_request, payload} -> payload
    after
      1_000 -> flunk("did not capture API request")
    end
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
