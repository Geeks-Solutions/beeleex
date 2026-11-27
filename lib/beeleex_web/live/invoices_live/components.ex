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

  attr :label, :string, required: true
  attr :value, :any, default: nil
  attr :class, :string, default: nil
  slot :inner_block

  def fact(assigns) do
    ~H"""
    <div class={@class}>
      <dt><%= @label %></dt>
      <dd><%= if @inner_block == [], do: known(@value), else: render_slot(@inner_block) %></dd>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :snapshot, :map, default: nil

  def party(assigns) do
    ~H"""
    <section id={@id} class="bx-invoice__party">
      <h2 class="bx-invoice__section-title"><%= @title %></h2>
      <%= if @snapshot do %>
        <p class="bx-invoice__party-name"><%= known(@snapshot[:name]) %></p>
        <address>
          <div :for={line <- address_lines(@snapshot[:address])}><%= line %></div>
        </address>
        <dl class="bx-invoice__facts">
          <.fact label={gettext("VAT number")} value={@snapshot[:vat_number]} />
          <.fact label={gettext("Registration number")} value={@snapshot[:registration_number]} />
          <.fact label={gettext("Source ID")} value={@snapshot[:source_id]} />
        </dl>
      <% else %>
        <p><%= gettext("Historical party snapshot not recorded.") %></p>
      <% end %>
    </section>
    """
  end

  defp address_lines(address) do
    street =
      Enum.join(
        Enum.reject([address[:street_number], address[:street_name]], &(&1 in [nil, ""])),
        " "
      )

    city =
      Enum.join(Enum.reject([address[:postal_code], address[:city]], &(&1 in [nil, ""])), " ")

    case Enum.reject([street, city, address[:country]], &(&1 in [nil, ""])) do
      [] -> [known(nil)]
      lines -> lines
    end
  end

  attr :invoice, Beeleex.Invoice, required: true

  def totals(assigns) do
    ~H"""
    <section id="invoice-totals" class="bx-invoice__totals">
      <h2 class="bx-invoice__section-title"><%= gettext("Invoice totals") %></h2>
      <dl class="bx-invoice__facts">
        <.fact label={gettext("Original net")} value={money(@invoice.amount_before_tax, @invoice)} />
        <.fact label={gettext("Original tax")}>
          <%= money(@invoice.tax_amount, @invoice) %>
          <small :if={@invoice.tax_rate && @invoice.accounting_data_status != "DRAFT"}>
            <%= gettext("Aggregate rate: %{rate}", rate: tax_rate(@invoice.tax_rate)) %>
          </small>
        </.fact>
        <.fact label={gettext("Original total")} value={money(@invoice.amount_with_tax, @invoice)} class="bx-invoice__gross" />
        <.fact label={gettext("Credited net")} value={money(@invoice.reduction_amount_before_tax, @invoice)} />
        <.fact label={gettext("Credited tax")} value={money(@invoice.reduction_tax_amount, @invoice)} />
        <.fact label={gettext("Credited total")} value={money(@invoice.reduction_amount_with_tax, @invoice)} />
        <.fact label={gettext("Outstanding balance")} value={money(@invoice.outstanding_amount, @invoice)} class="bx-invoice__balance" />
      </dl>
    </section>
    """
  end

  attr :invoice, Beeleex.Invoice, required: true

  def reporting(assigns) do
    ~H"""
    <section id="invoice-reporting" class="bx-invoice__reporting">
      <h2 class="bx-invoice__section-title"><%= gettext("Seller / reporting currency") %></h2>
      <dl class="bx-invoice__facts">
        <.fact label={gettext("Reporting currency / decimal places")}>
          <%= known(@invoice.seller_currency) %> / <%= known(@invoice.seller_decimal_places) %>
        </.fact>
        <.fact label={gettext("Exchange rate (reporting units per invoice unit)")}>
          <%= if @invoice.exchange_rate && @invoice.currency && @invoice.seller_currency do %>
            1 <%= @invoice.currency %> = <%= @invoice.exchange_rate %> <%= @invoice.seller_currency %>
          <% else %>
            <%= gettext("Not recorded") %>
          <% end %>
        </.fact>
      </dl>
      <dl class="bx-invoice__facts">
        <.fact label={gettext("Original reporting net")} value={reporting_money(@invoice.seller_amount_before_tax, @invoice)} />
        <.fact label={gettext("Original reporting tax")} value={reporting_money(@invoice.seller_tax_amount, @invoice)} />
        <.fact label={gettext("Original reporting total")} value={reporting_money(@invoice.seller_amount_with_tax, @invoice)} />
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
    <section class="bx-invoice__lines">
      <h2 class="bx-invoice__section-title"><%= gettext("Items and services") %></h2>
      <.table id="invoice-breakdown" rows={@lines} empty_message={gettext("No line items recorded")}>
        <:col :let={line} label={gettext("Description")}>
          <strong><%= line.kind %>: <%= known(line.name) %></strong>
          <small :if={line.description not in [nil, ""]}><%= line.description %></small>
          <small><%= known(line.project_name) %> (<%= known(line.project_id) %>)</small>
        </:col>
        <:col :let={line} label={gettext("Quantity")}><%= known(line.quantity) %></:col>
        <:col :let={line} label={gettext("Unit price (net)")}>
          <%= money(line.unit_price, @invoice) %>
        </:col>
        <:col :let={line} label={gettext("Net")}><%= money(line.net, @invoice) %></:col>
        <:col :let={line} label={gettext("Tax")}>
          <%= money(line.tax, @invoice) %>
          <small><%= tax_rate(line.tax_rate) %></small>
        </:col>
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
