defmodule BeeleexWeb.CompaniesLiveTest do
  use BeeleexWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mox

  # Run the mock in global mode so the LiveView process (a separate process)
  # sees the expectations, and verify them on exit.
  setup :set_mox_global
  setup :verify_on_exit!

  # The company details page embeds the invoices and payment-methods components,
  # which load on mount. Provide harmless defaults for tests that don't care.
  setup do
    stub(Beeleex.ApiMock, :get_invoices, fn _token, _opts ->
      {:ok, %{invoices: [], total: 0, count: 0}}
    end)

    stub(Beeleex.ApiMock, :get_payment_methods, fn _token, _opts ->
      {:ok, %{payment_methods: [], total: 0, count: 0}}
    end)

    :ok
  end

  defp company(attrs \\ %{}) do
    Map.merge(
      %Beeleex.Company{
        id: 1,
        name: "Acme Inc",
        email: "billing@acme.test",
        phone_number: "+1 555 0100",
        vat_number: "VAT123",
        registration_number: "REG999",
        solvency_status: "solvent",
        invoices_count: 3,
        payment_methods_count: 1,
        customer_projects: ["proj-a"],
        address: %{city: "Paris", country: "FR"}
      },
      attrs
    )
  end

  describe "Index" do
    test "lists companies", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_companies, fn _token, _opts ->
        {:ok, %{companies: [company(), company(%{id: 2, name: "Globex"})], total: 2, count: 2}}
      end)

      {:ok, _view, html} = live(conn, "/companies")

      assert html =~ "Acme Inc"
      assert html =~ "Globex"
      assert html =~ "billing@acme.test"
    end

    test "shows an error flash when the API fails", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_companies, fn _token, _opts -> {:error, "boom"} end)

      {:ok, _view, html} = live(conn, "/companies")

      assert html =~ "boom"
      assert html =~ "No companies yet"
    end

    test "searching patches with the query", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_companies, fn _token, _opts ->
        {:ok, %{companies: [company()], total: 1, count: 1}}
      end)

      {:ok, view, _html} = live(conn, "/companies")

      view
      |> form("form", %{"q" => "Acme"})
      |> render_submit()

      assert_patched(view, "/companies?q=Acme")
    end
  end

  describe "Show" do
    test "renders a company's details", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_company, fn _token, "1" -> {:ok, company()} end)

      {:ok, _view, html} = live(conn, "/companies/1")

      assert html =~ "Acme Inc"
      assert html =~ "VAT123"
      assert html =~ "proj-a"
    end

    test "deletes a company and redirects to the list", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_company, fn _token, "1" -> {:ok, company()} end)
      expect(Beeleex.ApiMock, :delete_company, fn _token, 1 -> {:ok, "deleted"} end)

      {:ok, view, _html} = live(conn, "/companies/1")

      render_click(view, "delete", %{})

      assert_redirect(view, "/companies")
    end

    test "unlinks a project", %{conn: conn} do
      stub(Beeleex.ApiMock, :get_company, fn _token, "1" -> {:ok, company()} end)

      expect(Beeleex.ApiMock, :unlink_project, fn _token, 1, "proj-a" ->
        {:ok, company(%{customer_projects: []})}
      end)

      {:ok, view, _html} = live(conn, "/companies/1")

      html = render_click(view, "unlink_project", %{"project" => "proj-a"})

      assert html =~ "Project unlinked"
      assert html =~ "No projects linked"
    end
  end

  describe "Show with show_linked_projects: false" do
    setup do
      Application.put_env(:beeleex, :show_linked_projects, false)
      on_exit(fn -> Application.delete_env(:beeleex, :show_linked_projects) end)

      stub(Beeleex.ApiMock, :get_company, fn _token, "1" -> {:ok, company()} end)
      :ok
    end

    test "hides the linked-projects section but keeps the rest of the page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/companies/1")

      refute html =~ "Linked projects"
      refute html =~ "proj-a"
      refute html =~ "Unlink"

      # Everything else still renders.
      assert html =~ "Acme Inc"
      assert html =~ "VAT123"
      assert html =~ "Invoices"
      assert html =~ "Payment methods"
    end

    test "ignores a forged unlink_project event instead of calling the API", %{conn: conn} do
      # No `expect` for :unlink_project — Mox fails the test if it is called.
      {:ok, view, _html} = live(conn, "/companies/1")

      html = render_click(view, "unlink_project", %{"project" => "proj-a"})

      refute html =~ "Project unlinked"
    end

    test "ignores a forged link_project event instead of calling the API", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/companies/1")

      html = render_click(view, "link_project", %{"project" => "proj-b"})

      refute html =~ "Project linked"
    end
  end

  describe "New" do
    test "creates a company and redirects to it", %{conn: conn} do
      expect(Beeleex.ApiMock, :create_company, fn _token, input ->
        assert input.name == "New Co"
        assert input.email == "new@co.test"
        {:ok, company(%{id: 7, name: "New Co"})}
      end)

      {:ok, view, _html} = live(conn, "/companies/new")

      view
      |> form("form", company: %{name: "New Co", email: "new@co.test"})
      |> render_submit()

      assert_redirect(view, "/companies/7")
    end

    test "shows validation errors for missing required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/companies/new")

      html =
        view
        |> form("form", company: %{name: "", email: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end
  end
end
