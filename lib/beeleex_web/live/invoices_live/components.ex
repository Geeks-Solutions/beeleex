defmodule BeeleexWeb.InvoicesLive.Components do
  @moduledoc "Presentation of stored invoice facts, without live-party or currency fallbacks."
  use BeeleexWeb, :html

  def invoice_title(%{invoice_reference: reference}) when reference not in [nil, ""],
    do: gettext("Invoice %{reference}", reference: reference)

  def invoice_title(%{invoice_number: number}) when not is_nil(number),
    do: gettext("Invoice number %{number}", number: number)

  def invoice_title(%{accounting_data_status: "DRAFT"}), do: gettext("Draft invoice")
  def invoice_title(%{accounting_data_status: "COMPLETE"}), do: gettext("Unnumbered invoice")
  def invoice_title(_invoice), do: gettext("Invoice — reference unavailable")

  def accounting_status("DRAFT"), do: gettext("Draft — not issued")
  def accounting_status("COMPLETE"), do: gettext("Complete accounting")
  def accounting_status("LEGACY_PARTIAL"), do: gettext("Incomplete historical accounting")
  def accounting_status(_status), do: gettext("Accounting data unavailable")

  def payment_status("pending_host"), do: gettext("Awaiting pricing")
  def payment_status("pending_payment"), do: gettext("Awaiting payment")
  def payment_status("payment_processing"), do: gettext("Payment processing")
  def payment_status("payment_failed"), do: gettext("Payment failed")
  def payment_status("payment_correction"), do: gettext("Payment correction")
  def payment_status("payment_retrying"), do: gettext("Retrying payment")
  def payment_status("payment_queued"), do: gettext("Payment queued")
  def payment_status("paid"), do: gettext("Paid")
  def payment_status(status), do: known(status)

  def known(value) when value in [nil, ""], do: gettext("Not recorded")
  def known(value), do: to_string(value)

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :snapshot, :map, default: nil

  def party(assigns) do
    ~H"""
    <section id={@id} class="bx-card">
      <h2 class="bx-subtitle"><%= @title %></h2>
      <%= if @snapshot do %>
        <dl class="bx-dl">
          <dt><%= gettext("Legal name") %></dt>
          <dd><%= known(@snapshot[:name]) %></dd>
          <dt><%= gettext("Source ID") %></dt>
          <dd><%= known(@snapshot[:source_id]) %></dd>
          <dt><%= gettext("VAT number") %></dt>
          <dd><%= known(@snapshot[:vat_number]) %></dd>
          <dt><%= gettext("Registration number") %></dt>
          <dd><%= known(@snapshot[:registration_number]) %></dd>
          <dt><%= gettext("Address") %></dt>
          <dd><%= snapshot_address(@snapshot[:address]) %></dd>
        </dl>
      <% else %>
        <p><%= gettext("Historical party snapshot not recorded.") %></p>
      <% end %>
    </section>
    """
  end

  defp snapshot_address(nil), do: known(nil)

  defp snapshot_address(address) do
    [:street_number, :street_name, :postal_code, :city, :country]
    |> Enum.map(&address[&1])
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
    |> known()
  end

  attr :invoice, Beeleex.Invoice, required: true

  def totals(assigns) do
    ~H"""
    <section id="invoice-totals" class="bx-card">
      <h2 class="bx-subtitle"><%= gettext("Invoice totals") %></h2>
      <dl class="bx-dl">
        <dt><%= gettext("Invoice currency / decimal places") %></dt>
        <dd><%= known(@invoice.currency) %> / <%= known(@invoice.decimal_places) %></dd>
        <dt><%= gettext("Original net") %></dt>
        <dd><%= money(@invoice.amount_before_tax, @invoice) %></dd>
        <dt><%= gettext("Original tax") %></dt>
        <dd><%= money(@invoice.tax_amount, @invoice) %></dd>
        <dt><%= gettext("Aggregate tax rate") %></dt>
        <dd><%= if @invoice.accounting_data_status == "DRAFT", do: "—", else: tax_rate(@invoice.tax_rate) %></dd>
        <dt><%= gettext("Original total") %></dt>
        <dd><%= money(@invoice.amount_with_tax, @invoice) %></dd>
        <dt><%= gettext("Credited net") %></dt>
        <dd><%= money(@invoice.reduction_amount_before_tax, @invoice) %></dd>
        <dt><%= gettext("Credited tax") %></dt>
        <dd><%= money(@invoice.reduction_tax_amount, @invoice) %></dd>
        <dt><%= gettext("Credited total") %></dt>
        <dd><%= money(@invoice.reduction_amount_with_tax, @invoice) %></dd>
        <dt><%= gettext("Outstanding balance") %></dt>
        <dd><%= money(@invoice.outstanding_amount, @invoice) %></dd>
      </dl>
    </section>
    """
  end

  attr :invoice, Beeleex.Invoice, required: true

  def reporting(assigns) do
    ~H"""
    <section id="invoice-reporting" class="bx-card">
      <h2 class="bx-subtitle"><%= gettext("Seller / reporting currency") %></h2>
      <dl class="bx-dl">
        <dt><%= gettext("Reporting currency / decimal places") %></dt>
        <dd><%= known(@invoice.seller_currency) %> / <%= known(@invoice.seller_decimal_places) %></dd>
        <dt><%= gettext("Exchange rate (reporting units per invoice unit)") %></dt>
        <dd>
          <%= if @invoice.exchange_rate && @invoice.currency && @invoice.seller_currency do %>
            1 <%= @invoice.currency %> = <%= @invoice.exchange_rate %> <%= @invoice.seller_currency %>
          <% else %>
            <%= gettext("Not recorded") %>
          <% end %>
        </dd>
        <dt><%= gettext("Original reporting net") %></dt>
        <dd><%= reporting_money(@invoice.seller_amount_before_tax, @invoice) %></dd>
        <dt><%= gettext("Original reporting tax") %></dt>
        <dd><%= reporting_money(@invoice.seller_tax_amount, @invoice) %></dd>
        <dt><%= gettext("Original reporting total") %></dt>
        <dd><%= reporting_money(@invoice.seller_amount_with_tax, @invoice) %></dd>
      </dl>
    </section>
    """
  end

  # The legacy API returns zero placeholders before pricing. They are not totals.
  def money(_amount, %{accounting_data_status: "DRAFT"} = invoice),
    do: format_money(nil, invoice.decimal_places, invoice.currency)

  def money(amount, invoice), do: format_money(amount, invoice.decimal_places, invoice.currency)

  defp reporting_money(amount, invoice),
    do: format_money(amount, invoice.seller_decimal_places, invoice.seller_currency)

  defp tax_rate(nil), do: "—"
  defp tax_rate(rate), do: format_amount(rate, 2) <> "%"

  attr :invoice, Beeleex.Invoice, required: true

  def lines(assigns) do
    assigns = assign(assigns, :lines, invoice_lines(assigns.invoice.breakdown || []))

    ~H"""
    <section class="bx-section">
      <h2 class="bx-subtitle"><%= gettext("Package and usage breakdown") %></h2>
      <.table id="invoice-breakdown" rows={@lines} empty_message={gettext("No line items recorded")}>
        <:col :let={line} label={gettext("Project")}>
          <%= known(line.project_name) %> (<%= known(line.project_id) %>)
        </:col>
        <:col :let={line} label={gettext("Item")}>
          <%= line.kind %>: <%= known(line.name) %>
          <p :if={line.description not in [nil, ""]}><%= line.description %></p>
        </:col>
        <:col :let={line} label={gettext("Quantity")}><%= known(line.quantity) %></:col>
        <:col :let={line} label={gettext("Unit price (net)")}>
          <%= money(line.unit_price, @invoice) %>
        </:col>
        <:col :let={line} label={gettext("Net")}><%= money(line.net, @invoice) %></:col>
        <:col :let={line} label={gettext("Tax rate")}><%= tax_rate(line.tax_rate) %></:col>
        <:col :let={line} label={gettext("Tax")}><%= money(line.tax, @invoice) %></:col>
        <:col :let={line} label={gettext("Gross")}><%= money(line.gross, @invoice) %></:col>
      </.table>
    </section>
    """
  end

  defp invoice_lines(packages) do
    Enum.flat_map(packages, fn package ->
      project = %{project_id: package[:project_id], project_name: package[:project_name]}

      package_line = %{
        kind: gettext("Package"),
        name: package[:package_name],
        description: package[:package_description],
        quantity: 1,
        unit_price: package[:package_price_before_tax],
        net: package[:package_price_before_tax],
        tax_rate: package[:package_tax_rate],
        tax: package[:package_tax],
        gross: package[:package_price_with_tax]
      }

      usage_lines = Enum.map(package[:pay_as_you_go] || [], &usage_line/1)
      Enum.map([package_line | usage_lines], &Map.merge(&1, project))
    end)
  end

  defp usage_line(usage) do
    %{
      kind: gettext("Usage"),
      name: usage[:name],
      description: usage[:description],
      quantity: usage[:quantity],
      unit_price: usage[:unit_price_before_tax],
      net: usage[:total_before_tax],
      tax_rate: usage[:tax_rate],
      tax: usage[:tax],
      gross: usage[:total_with_tax]
    }
  end
end
