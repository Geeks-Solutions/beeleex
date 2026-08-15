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
    stub(Beeleex.ApiMock, :get_company, fn _token, "1" -> {:ok, company()} end)
    stub(Beeleex.ApiMock, :get_invoices, fn _token, _ -> {:ok, %{invoices: [], total: 0, count: 0}} end)
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
    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      {:ok, %{payment_methods: [payment_method()], total: 1, count: 1}}
    end)

    expect(Beeleex.ApiMock, :make_default_payment_method, fn _token, 1, "5" ->
      {:ok, "stripe_card"}
    end)

    {:ok, view, _html} = live(conn, "/companies/1")

    view
    |> element("button[phx-click=make_default][phx-value-id=5]")
    |> render_click()
  end

  test "adding a payment method requests a setup intent and pushes the Stripe event",
       %{conn: conn} do
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

  test "deactivating a method calls the API", %{conn: conn} do
    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      {:ok, %{payment_methods: [payment_method()], total: 1, count: 1}}
    end)

    expect(Beeleex.ApiMock, :deactivate_payment_method, fn _token, "5" -> {:ok, "deactivated"} end)

    {:ok, view, _html} = live(conn, "/companies/1")

    view
    |> element("button[phx-click=deactivate][phx-value-id=5]")
    |> render_click()
  end
end
