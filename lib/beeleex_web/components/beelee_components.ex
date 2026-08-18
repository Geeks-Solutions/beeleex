defmodule BeeleexWeb.BeeleeComponents do
  @moduledoc """
  Reusable UI building blocks for the Beeleex LiveView pages.

  These are Phoenix/HEEx components used by the bundled LiveView pages.

  ## Styling & theming

  The markup uses **semantic class names** (`bx-table`, `bx-btn`, `bx-input`, …)
  and ships a default stylesheet (`priv/static/beeleex/beeleex.css`) scoped under
  the `.beeleex` root wrapper. The look is driven by CSS custom properties, so a
  host application themes the whole UI by overriding a few variables (e.g.
  `--bx-primary`, `--bx-radius`, `--bx-font`) — no Tailwind or build step
  required. See `docs/integration/theming.md`.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  use Gettext, backend: BeeleexWeb.Gettext

  @doc """
  A generic data table.

  ## Example

      <.table id="companies" rows={@companies} row_click={fn c -> JS.navigate("/companies/\#{c.id}") end}>
        <:col :let={company} label="Name"><%= company.name %></:col>
        <:action :let={company}>
          <.link navigate={"/companies/\#{company.id}"}>View</.link>
        </:action>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling row click"
  attr :row_item, :any, default: &Function.identity/1, doc: "maps each row before slots"
  attr :empty_message, :string, default: nil

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    ~H"""
    <div class="bx-table-wrap">
      <table class="bx-table" id={@id}>
        <thead>
          <tr>
            <th :for={col <- @col}><%= col[:label] %></th>
            <th :if={@action != []}><span class="bx-sr-only"><%= gettext("Actions") %></span></th>
          </tr>
        </thead>
        <tbody id={"#{@id}-tbody"}>
          <tr :if={@rows in [nil, []]} class="bx-table-empty">
            <td colspan={length(@col) + 1}>
              <%= @empty_message || gettext("No records found") %>
            </td>
          </tr>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class={["bx-row", @row_click && "bx-row--clickable"]}
          >
            <td :for={col <- @col} phx-click={@row_click && @row_click.(row)}>
              <%= render_slot(col, @row_item.(row)) %>
            </td>
            <td :if={@action != []} class="bx-cell--actions">
              <%= for action <- @action do %>
                <%= render_slot(action, @row_item.(row)) %>
              <% end %>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Pagination control driven by URL patches.

  `total` is the total number of records, `size` the page size, `page` the
  current 1-based page, and `path` a function `page -> url`.
  """
  attr :page, :integer, required: true
  attr :size, :integer, required: true
  attr :total, :integer, required: true
  attr :path, :any, required: true, doc: "fn page -> url"

  def pagination(assigns) do
    page_count = max(1, ceil(assigns.total / max(assigns.size, 1)))
    assigns = assign(assigns, :page_count, page_count)

    ~H"""
    <nav :if={@page_count > 1} class="bx-pagination" aria-label="Pagination">
      <.link :if={@page > 1} patch={@path.(@page - 1)} class="bx-btn bx-btn--ghost">
        <%= gettext("Previous") %>
      </.link>
      <span class="bx-pagination__info">
        <%= gettext("Page %{page} of %{count}", page: @page, count: @page_count) %>
      </span>
      <.link :if={@page < @page_count} patch={@path.(@page + 1)} class="bx-btn bx-btn--ghost">
        <%= gettext("Next") %>
      </.link>
    </nav>
    """
  end

  @doc """
  Flash / alert message.
  """
  attr :kind, :atom, values: [:info, :error], required: true
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  slot :inner_block

  def flash_alert(assigns) do
    assigns =
      assign_new(assigns, :message, fn -> Phoenix.Flash.get(assigns.flash, assigns.kind) end)

    ~H"""
    <p
      :if={msg = render_slot(@inner_block) || @message}
      role="alert"
      class={["bx-alert", "bx-alert--#{@kind}"]}
    >
      <strong :if={@title}><%= @title %></strong>
      <%= msg %>
    </p>
    """
  end

  @doc """
  A status badge. Pass `tone` to colour it (`:success`, `:warning`, `:danger`,
  or `:neutral`).
  """
  attr :tone, :atom, default: :neutral, values: [:neutral, :success, :warning, :danger]
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={["bx-badge", @tone != :neutral && "bx-badge--#{@tone}"]}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  @doc """
  A modal dialog.

  Show/hide it with `show_modal/1` and `hide_modal/1`, or render it open by
  passing `show={true}`. `on_cancel` is a `JS` command run when dismissed.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div id={@id} class="bx-modal" hidden={!@show} phx-mounted={@show && show_modal(@id)}>
      <div class="bx-modal__overlay" aria-hidden="true" phx-click={hide_modal(@on_cancel, @id)}></div>
      <div class="bx-modal__content" role="dialog" aria-modal="true">
        <button
          type="button"
          class="bx-modal__close"
          phx-click={hide_modal(@on_cancel, @id)}
          aria-label={gettext("Close")}
        >
          ✕
        </button>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  @doc """
  A button. Use `variant` for the visual style and `class` for extra classes.
  """
  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary", values: ~w(primary danger ghost)
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value phx-click phx-target phx-value-id)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button type={@type} class={["bx-btn", "bx-btn--#{@variant}", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  A labelled form input. Accepts a `Phoenix.HTML.FormField` via the `field`
  attribute.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :rest, :global, include: ~w(autocomplete disabled placeholder readonly required)
  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(assigns) do
    ~H"""
    <div class="bx-field">
      <label :if={@label} for={@id} class="bx-label"><%= @label %></label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={["bx-input", @errors != [] && "bx-input--invalid"]}
        {@rest}
      />
      <p :for={msg <- @errors} class="bx-error"><%= msg %></p>
    </div>
    """
  end

  @doc """
  Format a Beelee monetary amount. Beelee returns amounts as integers in minor
  units together with a `decimalPlaces` value, e.g. `1050` / `2` -> `"10.50"`.
  """
  def format_amount(amount, decimal_places \\ 2)
  def format_amount(nil, _decimal_places), do: "—"

  def format_amount(amount, decimal_places) when is_integer(amount) do
    dp = decimal_places || 2
    :erlang.float_to_binary(amount / :math.pow(10, dp), decimals: dp)
  end

  def format_amount(amount, _decimal_places), do: to_string(amount)

  @doc """
  Maps an invoice/payment status to a `<.badge>` tone.
  """
  def invoice_status_tone("paid"), do: :success
  def invoice_status_tone("pending"), do: :warning
  def invoice_status_tone(status) when status in ["failed", "unpaid"], do: :danger
  def invoice_status_tone(_status), do: :neutral

  @doc "Shows a modal by id."
  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    JS.remove_attribute(js, "hidden", to: "##{id}")
  end

  @doc "Hides a modal by id."
  def hide_modal(js \\ %JS{}, id) do
    JS.set_attribute(js, {"hidden", "hidden"}, to: "##{id}")
  end

  defp translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(BeeleexWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(BeeleexWeb.Gettext, "errors", msg, opts)
    end
  end

  defp translate_error(msg) when is_binary(msg), do: msg
end
