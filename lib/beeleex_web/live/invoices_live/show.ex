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
    <div class="bx-page">
      <.link navigate={@company_path} class="bx-back"><%= gettext("← Back to company") %></.link>

      <div class="bx-header">
        <h1 class="bx-title">
          <%= invoice_title(@invoice) %>
        </h1>
        <.badge tone={invoice_status_tone(@invoice.status)}>
          <%= payment_status(@invoice.status) %>
        </.badge>
        <.badge><%= accounting_status(@invoice.accounting_data_status) %></.badge>
      </div>

      <p :if={@invoice.accounting_data_status != "COMPLETE"} class="bx-notice">
        <%= gettext("Accounting facts may be incomplete. Missing values are not zero; live company data is not used for historical parties.") %>
      </p>

      <section class="bx-card bx-invoice-summary">
        <dl class="bx-dl">
          <dt><%= gettext("Official reference") %></dt>
          <dd><%= known(@invoice.invoice_reference) %></dd>
          <dt><%= gettext("Official number") %></dt>
          <dd><%= known(@invoice.invoice_number) %></dd>
          <dt><%= gettext("Internal ID") %></dt>
          <dd><%= @invoice.id %></dd>
          <dt><%= gettext("Issued at (UTC)") %></dt>
          <dd><%= known(@invoice.issued_at) %></dd>
          <dt><%= gettext("Tax point date") %></dt>
          <dd><%= known(@invoice.tax_point_date) %></dd>
          <dt><%= gettext("Due date") %></dt>
          <dd><%= known(@invoice.due_date) %></dd>
          <dt><%= gettext("Settled at") %></dt>
          <dd><%= known(@invoice.closing_date) %></dd>
          <dt><%= gettext("Record created at") %></dt>
          <dd><%= known(@invoice.inserted_at) %></dd>
          <dt><%= gettext("Type") %></dt>
          <dd><%= known(@invoice.type) %></dd>
          <%= if @invoice.cycle not in [nil, ""] do %>
            <dt><%= gettext("Cycle") %></dt>
            <dd><%= @invoice.cycle %></dd>
          <% end %>
          <%= if @invoice.beginning not in [nil, ""] or @invoice.end not in [nil, ""] do %>
            <dt><%= gettext("Period") %></dt>
            <dd><%= @invoice.beginning %> → <%= @invoice.end %></dd>
          <% end %>
        </dl>

      </section>

      <.party id="invoice-seller" title={gettext("Seller (stored snapshot)")} snapshot={@invoice.seller_snapshot} />
      <.party id="invoice-buyer" title={gettext("Buyer (stored snapshot)")} snapshot={@invoice.buyer_snapshot} />
      <.totals invoice={@invoice} />
      <.lines invoice={@invoice} />
      <.reporting invoice={@invoice} />
    </div>
    """
  end

  defp companies_base(uri) do
    %URI{path: path} = URI.parse(uri)
    [head | _] = String.split(path, "/companies")
    head <> "/companies"
  end
end
