defmodule BeeleexWeb.PaymentMethodsLiveTest do
  use BeeleexWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  defp company(attrs \\ %{}) do
    Map.merge(
      %Beeleex.Company{id: 1, name: "Acme Inc", customer_projects: [], address: %{}},
      attrs
    )
  end

  defp payment_method(attrs \\ %{}) do
    Map.merge(
      %{
        id: 5,
        type: "stripe_card",
        status: "active",
        default_payment_method: false,
        stripe_card: %{brand: "visa", last4: "4242", exp_month: 12, exp_year: 2030}
      },
      attrs
    )
  end

  setup do
    # The company show page also embeds the invoices list.
    stub(Beeleex.ApiMock, :get_company, fn _token, _company_id -> {:ok, company()} end)

    stub(Beeleex.ApiMock, :get_invoices, fn _token, _ ->
      {:ok, %{invoices: [], total: 0, count: 0}}
    end)

    :ok
  end

  test "lists a company's payment methods", %{conn: conn} do
    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, opts ->
      assert [%{key: "company_id", value: "1"}] = Keyword.fetch!(opts, :filter)
      {:ok, %{payment_methods: [payment_method()], total: 1, count: 1}}
    end)

    {:ok, _view, html} = live(conn, "/companies/1")

    assert html =~ "visa"
    assert html =~ "4242"
    assert html =~ "12/2030"
  end

  test "making a method default reloads the list", %{conn: conn} do
    Process.delete(:get_payment_methods_calls)

    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      calls = (Process.get(:get_payment_methods_calls) || 0) + 1
      Process.put(:get_payment_methods_calls, calls)

      case calls do
        1 ->
          {:ok, %{payment_methods: [payment_method()], total: 1, count: 1}}

        _ ->
          {:ok,
           %{
             payment_methods: [payment_method(%{default_payment_method: true})],
             total: 1,
             count: 1
           }}
      end
    end)

    expect(Beeleex.ApiMock, :make_default_payment_method, fn _token, 1, "5" ->
      {:ok, "stripe_card"}
    end)

    {:ok, view, _html} = live(conn, "/companies/1")

    view
    |> element("button[phx-click=make_default][phx-value-id=5]")
    |> render_click()

    assert render(view) =~ "Default"
  end

  test "default action accepts string payment method ids", %{conn: conn} do
    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      {:ok,
       %{
         payment_methods: [payment_method(%{id: "5", default_payment_method: false})],
         total: 1,
         count: 1
       }}
    end)

    expect(Beeleex.ApiMock, :make_default_payment_method, fn _token, 1, "5" ->
      {:ok, "stripe_card"}
    end)

    {:ok, view, _html} = live(conn, "/companies/1")

    view
    |> element("button[phx-click=make_default][phx-value-id=5]")
    |> render_click()

    assert render(view) =~ "Default"
  end

  test "adding a payment method requests a setup intent and pushes the Stripe event", %{
    conn: conn
  } do
    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      {:ok, %{payment_methods: [], total: 0, count: 0}}
    end)

    expect(Beeleex.ApiMock, :request_setup_intent, fn _token, 1 ->
      {:ok, %{client_secret: "seti_secret_123", publishable_key: "pk_test_1", verified: true}}
    end)

    {:ok, view, _html} = live(conn, "/companies/1")

    view
    |> element("button[phx-click=add_payment_method]")
    |> render_click()

    assert_push_event(view, "beeleex:init_stripe", %{
      client_secret: "seti_secret_123",
      publishable_key: "pk_test_1"
    })
  end

  test "adding a payment method verifies and confirms when the card appears", %{conn: conn} do
    Process.delete(:get_payment_methods_calls)

    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      calls = (Process.get(:get_payment_methods_calls) || 0) + 1
      Process.put(:get_payment_methods_calls, calls)

      case calls do
        1 ->
          {:ok, %{payment_methods: [], total: 0, count: 0}}

        2 ->
          {:ok, %{payment_methods: [], total: 0, count: 0}}

        _ ->
          {:ok,
           %{
             payment_methods: [
               payment_method(%{
                 id: 8,
                 stripe_card: %{
                   stripe_id: "pm_test_added",
                   brand: "visa",
                   last4: "4242",
                   exp_month: 12,
                   exp_year: 2030
                 }
               })
             ],
             total: 1,
             count: 1
           }}
      end
    end)

    expect(Beeleex.ApiMock, :request_setup_intent, fn _token, 1 ->
      {:ok, %{client_secret: "seti_secret_123", publishable_key: "pk_test_1", verified: true}}
    end)

    {:ok, view, _html} = live(conn, "/companies/1")

    view
    |> element("button[phx-click=add_payment_method]")
    |> render_click()

    updated_html =
      view
      |> element("#company-1-payment-methods")
      |> render_hook(:payment_method_added, %{payment_method: "pm_test_added"})

    assert updated_html =~ "Card attached and is being verified with a 1 EUR authorization"

    Process.sleep(1_100)

    final_html = render(view)

    assert final_html =~ "Payment method added successfully"
    assert final_html =~ "visa"
    assert final_html =~ "4242"
  end

  test "adding a payment method shows a verification error when card is not found", %{conn: conn} do
    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      {:ok, %{payment_methods: [], total: 0, count: 0}}
    end)

    expect(Beeleex.ApiMock, :request_setup_intent, fn _token, 1 ->
      {:ok, %{client_secret: "seti_secret_123", publishable_key: "pk_test_1", verified: true}}
    end)

    {:ok, view, _html} = live(conn, "/companies/1")

    view
    |> element("button[phx-click=add_payment_method]")
    |> render_click()

    updated_html =
      view
      |> element("#company-1-payment-methods")
      |> render_hook(:payment_method_added, %{payment_method: "pm_test_added"})

    assert updated_html =~ "Card attached and is being verified with a 1 EUR authorization"

    # five polling attempts, each one second, then a timeout.
    Process.sleep(5_600)

    final_html = render(view)

    assert final_html =~
             "The card could not be verified. Please make sure this card has enough funds and try again."

    refute final_html =~ "Card attached and is being verified with a 1 EUR authorization"
  end

  test "adding a payment method shows the API error on setup intent failure", %{conn: conn} do
    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      {:ok, %{payment_methods: [], total: 0, count: 0}}
    end)

    expect(Beeleex.ApiMock, :request_setup_intent, fn _token, 1 ->
      {:error, "Could not start card setup"}
    end)

    {:ok, view, _html} = live(conn, "/companies/1")

    html =
      view
      |> element("button[phx-click=add_payment_method]")
      |> render_click()

    assert html =~ "Could not start card setup"
  end

  test "deactivating a method calls the API", %{conn: conn} do
    Process.delete(:get_payment_methods_calls)

    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      calls = (Process.get(:get_payment_methods_calls) || 0) + 1
      Process.put(:get_payment_methods_calls, calls)

      case calls do
        1 ->
          {:ok, %{payment_methods: [payment_method()], total: 1, count: 1}}

        _ ->
          {:ok, %{payment_methods: [payment_method(%{status: "inactive"})], total: 1, count: 1}}
      end
    end)

    expect(Beeleex.ApiMock, :deactivate_payment_method, fn _token, "5" -> {:ok, "inactive"} end)

    {:ok, view, _html} = live(conn, "/companies/1")

    html = render(view)
    assert html =~ "Deactivate"
    refute html =~ "Retry"

    view
    |> element("button[phx-click=deactivate][phx-value-id=5]")
    |> render_click()

    refute render(view) =~ "Make default"
    assert render(view) =~ "Retry"
  end

  test "inactive card shows retry action", %{conn: conn} do
    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      {:ok, %{payment_methods: [payment_method(%{status: "inactive"})], total: 1, count: 1}}
    end)

    expect(Beeleex.ApiMock, :reactivate_payment_method, fn _token, "5" -> {:ok, "active"} end)

    {:ok, view, _html} = live(conn, "/companies/1")

    assert render(view) =~ "Retry"
    refute render(view) =~ "Make default"
    refute render(view) =~ "Deactivate"

    view
    |> element("button[phx-click=reactivate][phx-value-id=5]")
    |> render_click()
  end
end
