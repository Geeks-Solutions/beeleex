defmodule BeeleexWeb.InvoicesLive.Show do
  @moduledoc """
  Read-only view of a single invoice.
  """
  use BeeleexWeb, :live_view
  import BeeleexWeb.InvoicesLive.Components

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       company_path: "/companies",
       invoice: nil,
       api_module: api_module(session),
       bu_token: BeeleexWeb.LiveSession.bu_token(session)
     )}
  end

  defp api_module(session), do: Map.get(session, "beeleex_api_module", Beeleex.Api)

  @impl true
  def handle_params(%{"id" => company_id, "invoice_id" => invoice_id}, uri, socket) do
    company_path = companies_base(uri) <> "/#{company_id}"

    case socket.assigns.api_module.get_invoice(socket.assigns.bu_token, invoice_id) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> assign(:page_title, invoice_title(invoice))
         |> assign(:company_path, company_path)
         |> assign(:invoice, invoice)}

      {:error, message} ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> push_navigate(to: company_path)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bx-page bx-invoice">
      <.link navigate={@company_path} class="bx-back"><%= gettext("← Back to company") %></.link>

      <article class="bx-card bx-invoice__document" aria-labelledby="invoice-title">
        <header class="bx-invoice__header">
          <h1 id="invoice-title" class="bx-title"><%= invoice_title(@invoice) %></h1>
          <div class="bx-invoice__status">
            <.badge tone={invoice_status_tone(@invoice.status)}>
              <%= payment_status(@invoice.status) %>
            </.badge>
            <p><%= accounting_status(@invoice.accounting_data_status) %></p>
          </div>
        </header>

        <p :if={@invoice.accounting_data_status == "DRAFT"} class="bx-invoice__notice">
          <%= gettext("This invoice has not been issued. Totals are unavailable until pricing.") %>
        </p>
        <p :if={@invoice.accounting_data_status not in ["DRAFT", "COMPLETE"]} class="bx-invoice__notice">
          <%= gettext("Some historical accounting details may be missing. Missing amounts are shown as a dash.") %>
        </p>

        <div class="bx-invoice__parties">
          <.party id="invoice-seller" title={gettext("From · Seller")} snapshot={@invoice.seller_snapshot} />
          <.party id="invoice-buyer" title={gettext("Bill to · Buyer")} snapshot={@invoice.buyer_snapshot} />
        </div>

        <dl class="bx-invoice__facts bx-invoice-summary">
          <.fact label={gettext("Issued at (UTC)")} value={@invoice.issued_at} />
          <.fact label={gettext("Tax point date")} value={@invoice.tax_point_date} />
          <.fact label={gettext("Due date")} value={@invoice.due_date} />
          <.fact :if={@invoice.beginning || @invoice.end} label={gettext("Billing period")}>
            <%= known(@invoice.beginning) %> → <%= known(@invoice.end) %>
          </.fact>
          <.fact label={gettext("Type / cycle")}>
            <%= known(@invoice.type) %>
            <%= if @invoice.cycle, do: " / #{@invoice.cycle}" %>
          </.fact>
          <.fact label={gettext("Invoice currency / decimal places")}>
            <%= known(@invoice.currency) %> / <%= known(@invoice.decimal_places) %>
          </.fact>
        </dl>

        <.lines invoice={@invoice} />

        <div class="bx-invoice__settlement">
          <dl class="bx-invoice__facts">
            <.fact label={gettext("Settled at")} value={@invoice.closing_date} />
          </dl>
          <.totals invoice={@invoice} />
        </div>

        <.reporting invoice={@invoice} />

        <footer class="bx-invoice__footer">
          <dl class="bx-invoice__facts">
            <.fact label={gettext("Official number")} value={@invoice.invoice_number} />
            <.fact label={gettext("Internal ID")} value={@invoice.id} />
            <.fact label={gettext("Record created at")} value={@invoice.inserted_at} />
          </dl>
        </footer>
      </article>
    </div>
    """
  end

  defp companies_base(uri) do
    %URI{path: path} = URI.parse(uri)
    [head | _] = String.split(path, "/companies")
    head <> "/companies"
  end
end
