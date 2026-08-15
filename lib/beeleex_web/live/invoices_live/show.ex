defmodule BeeleexWeb.InvoicesLive.Show do
  @moduledoc """
  Read-only view of a single invoice.
  """
  use BeeleexWeb, :live_view

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
         |> assign(:page_title, gettext("Invoice #%{id}", id: invoice.id))
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
          <%= gettext("Invoice #%{id}", id: @invoice.id) %>
        </h1>
        <.badge tone={invoice_status_tone(@invoice.status)}><%= @invoice.status %></.badge>
      </div>

      <section class="bx-card bx-invoice-summary">
        <dl class="bx-dl">
          <dt><%= gettext("Type") %></dt>
          <dd><%= @invoice.type %></dd>
          <%= if @invoice.cycle not in [nil, ""] do %>
            <dt><%= gettext("Cycle") %></dt>
            <dd><%= @invoice.cycle %></dd>
          <% end %>
          <%= if @invoice.beginning not in [nil, ""] or @invoice.end not in [nil, ""] do %>
            <dt><%= gettext("Period") %></dt>
            <dd><%= @invoice.beginning %> → <%= @invoice.end %></dd>
          <% end %>
        </dl>

        <dl class="bx-invoice-totals">
          <div class="bx-invoice-totals__row">
            <dt><%= gettext("Amount before tax") %></dt>
            <dd><%= format_amount(@invoice.amount_before_tax, @invoice.decimal_places) %></dd>
          </div>
          <div class="bx-invoice-totals__row">
            <dt><%= gettext("Tax") %></dt>
            <dd><%= format_amount(@invoice.tax_amount, @invoice.decimal_places) %></dd>
          </div>
          <div class="bx-invoice-totals__row bx-invoice-totals__row--total">
            <dt><%= gettext("Amount with tax") %></dt>
            <dd><%= format_amount(@invoice.amount_with_tax, @invoice.decimal_places) %></dd>
          </div>
        </dl>
      </section>

      <section :if={@invoice.breakdown not in [nil, []]} class="bx-section">
        <h2 class="bx-subtitle"><%= gettext("Breakdown") %></h2>
        <.table id="invoice-breakdown" rows={@invoice.breakdown || []}>
          <:col :let={line} label={gettext("Project")}><%= line[:project_name] %></:col>
          <:col :let={line} label={gettext("Package")}><%= line[:package_name] %></:col>
          <:col :let={line} label={gettext("Price before tax")}>
            <%= format_amount(line[:package_price_before_tax], @invoice.decimal_places) %>
          </:col>
        </.table>
      </section>
    </div>
    """
  end

  defp companies_base(uri) do
    %URI{path: path} = URI.parse(uri)
    [head | _] = String.split(path, "/companies")
    head <> "/companies"
  end
end
