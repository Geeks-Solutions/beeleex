defmodule BeeleexWeb.PaymentMethodsLive.ListComponent do
  @moduledoc """
  Embeddable list of a company's payment methods. Supports making a method the
  default, deactivating and retrying a method, and adding a new card via a Stripe
  SetupIntent.

  ## Adding a card (Stripe)

  Adding a card is the one genuinely client-side flow. When the user clicks
  "Add payment method" the server calls `Beeleex.Api.request_setup_intent/1` and
  pushes a `"beeleex:init_stripe"` event carrying the `client_secret` and
  `publishable_key`. The JavaScript hook `BeeleexStripeSetup`
  (`priv/static/beeleex/beeleex_hooks.js`) loads Stripe.js, mounts a card
  element, and on confirmation calls `stripe.confirmCardSetup/2`. On success it
  pushes `"payment_method_added"` back to this component, which refreshes the
  list. See `docs/integration/liveview-pages.md` for host wiring.

  ## Required assigns

    * `:id` - the component id (also used as the Stripe hook root id)
    * `:company_id` - the company whose payment methods to manage
    * `:bu_token` - the signed-in user's Beelee token (for `bu-authorization`)
  """
  use BeeleexWeb, :live_component

  require Logger

  # Beelee records a freshly added card asynchronously (via a Stripe webhook), so
  # the reload right after "Save card" can race ahead of it and show an empty
  # list. After adding, re-check the list on this backoff until the new method
  # appears (or the attempts run out).
  @reload_delays_ms [1200, 3000, 6000]

  @impl true
  # Re-check after adding a card: reload, and if the new method still isn't
  # visible, schedule the next attempt. Driven by `send_update/3` from a task.
  def update(%{reload_if_stale: {before_count, rest}}, socket) do
    socket = load(socket)
    now_count = length(socket.assigns.payment_methods)

    Logger.info(
      "[beeleex] payment_methods reload-if-stale id=#{socket.assigns.id} " <>
        "before=#{before_count} now=#{now_count} remaining_attempts=#{length(rest)}"
    )

    if now_count <= before_count do
      schedule_reload(self(), socket.assigns.id, before_count, rest)
    end

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      socket
      |> assign_new(:adding, fn -> false end)
      |> assign_new(:error, fn -> nil end)

    # Skip the Beelee fetch during the static (disconnected) render — it would be
    # discarded and refetched on connect, and each fetch triggers a Beelee
    # `verify_token` callback. Fetch only once, on the connected render.
    socket =
      cond do
        socket.assigns[:loaded] -> socket
        connected?(socket) -> load(socket)
        true -> assign(socket, payment_methods: [])
      end

    {:ok, socket}
  end

  defp load(socket) do
    filter = [%{key: "company_id", value: to_string(socket.assigns.company_id)}]

    case socket.assigns.api_module.get_payment_methods(socket.assigns.bu_token,
           filter: filter,
           size: 50
         ) do
      {:ok, %{payment_methods: methods}} ->
        Logger.info(
          "[beeleex] get_payment_methods OK company_id=#{socket.assigns.company_id} " <>
            "count=#{length(methods)} ids=#{inspect(Enum.map(methods, & &1[:id]))}"
        )

        assign(socket, payment_methods: methods, loaded: true, error: nil)

      {:error, message} ->
        Logger.error(
          "[beeleex] get_payment_methods ERROR company_id=#{socket.assigns.company_id} " <>
            "message=#{inspect(message)}"
        )

        assign(socket, payment_methods: [], loaded: true, error: message)
    end
  end

  # Schedule the next stale-reload attempt from a detached task. `send_update/3`
  # can target the LiveView from any process, so this needs no `handle_info` in
  # the host page. Stops once `rest` is exhausted.
  defp schedule_reload(_lv_pid, _id, _before_count, []), do: :ok

  defp schedule_reload(lv_pid, id, before_count, [delay | rest]) do
    Task.start(fn ->
      Process.sleep(delay)

      Phoenix.LiveView.send_update(lv_pid, __MODULE__,
        id: id,
        reload_if_stale: {before_count, rest}
      )
    end)

    :ok
  end

  @impl true
  def handle_event("add_payment_method", _params, socket) do
    case socket.assigns.api_module.request_setup_intent(
           socket.assigns.bu_token,
           socket.assigns.company_id
         ) do
      {:ok, %{client_secret: secret, publishable_key: key}} ->
        Logger.info(
          "[beeleex] request_setup_intent OK company_id=#{socket.assigns.company_id} " <>
            "publishable_key=#{inspect(key)} client_secret_present=#{secret not in [nil, ""]}"
        )

        {:noreply,
         socket
         |> assign(adding: true, error: nil)
         |> push_event("beeleex:init_stripe", %{
           client_secret: secret,
           publishable_key: key,
           target: "##{socket.assigns.id}"
         })}

      {:error, message} ->
        Logger.error(
          "[beeleex] request_setup_intent ERROR company_id=#{socket.assigns.company_id} " <>
            "message=#{inspect(message)}"
        )

        {:noreply, assign(socket, :error, message)}
    end
  end

  def handle_event("cancel_add", _params, socket) do
    {:noreply, assign(socket, :adding, false)}
  end

  def handle_event("payment_method_added", params, socket) do
    Logger.info(
      "[beeleex] payment_method_added event received id=#{socket.assigns.id} " <>
        "company_id=#{socket.assigns.company_id} params=#{inspect(params)}"
    )

    send(self(), {:payment_methods_updated, socket.assigns.company_id})

    # Reload now (optimistic), then keep re-checking so a card that Beelee only
    # records once its Stripe webhook lands still shows up without a refresh.
    schedule_reload(
      self(),
      socket.assigns.id,
      length(socket.assigns.payment_methods),
      @reload_delays_ms
    )

    {:noreply, socket |> assign(:adding, false) |> load()}
  end

  def handle_event("make_default", %{"id" => id}, socket) do
    run(socket, fn ->
      socket.assigns.api_module.make_default_payment_method(
        socket.assigns.bu_token,
        socket.assigns.company_id,
        id
      )
    end)
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    run(socket, fn ->
      socket.assigns.api_module.deactivate_payment_method(socket.assigns.bu_token, id)
    end)
  end

  def handle_event("reactivate", %{"id" => id}, socket) do
    run(socket, fn ->
      socket.assigns.api_module.reactivate_payment_method(socket.assigns.bu_token, id)
    end)
  end

  defp run(socket, fun) do
    case fun.() do
      {:ok, _} ->
        send(self(), {:payment_methods_updated, socket.assigns.company_id})
        {:noreply, load(socket)}

      {:error, message} ->
        {:noreply, assign(socket, :error, message)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} phx-hook="BeeleexStripeSetup" class="beeleex-payment-methods">
      <.flash_alert :if={@error} kind={:error}><%= @error %></.flash_alert>

      <.table id={"#{@id}-table"} rows={@payment_methods} empty_message={gettext("No payment methods yet")}>
        <:col :let={pm} label={gettext("Card")}>
          <%= card_brand(pm) %> •••• <%= card_last4(pm) %>
        </:col>
        <:col :let={pm} label={gettext("Expires")}><%= card_expiry(pm) %></:col>
        <:col :let={pm} label={gettext("Status")}>
          <.badge tone={pm_tone(pm[:status])}><%= pm[:status] %></.badge>
        </:col>
        <:col :let={pm} label={gettext("Default")}>
          <.badge :if={pm[:default_payment_method]} tone={:success}><%= gettext("Default") %></.badge>
        </:col>
        <:action :let={pm}>
          <button
            :if={!pm[:default_payment_method]}
            type="button"
            phx-click="make_default"
            phx-value-id={pm[:id]}
            phx-target={@myself}
            class="bx-action"
          >
            <%= gettext("Make default") %>
          </button>
        </:action>
        <:action :let={pm}>
          <button
            :if={pm[:status] != "deactivated"}
            type="button"
            phx-click="deactivate"
            phx-value-id={pm[:id]}
            phx-target={@myself}
            data-confirm={gettext("Deactivate this payment method?")}
            class="bx-action bx-action--danger"
          >
            <%= gettext("Deactivate") %>
          </button>
          <button
            :if={pm[:status] == "deactivated"}
            type="button"
            phx-click="reactivate"
            phx-value-id={pm[:id]}
            phx-target={@myself}
            class="bx-action"
          >
            <%= gettext("Retry") %>
          </button>
        </:action>
      </.table>

      <button
        type="button"
        phx-click="add_payment_method"
        phx-target={@myself}
        class="bx-btn bx-btn--primary"
        style="margin-top: 0.85rem;"
      >
        <%= gettext("Add payment method") %>
      </button>

      <div :if={@adding} class="bx-modal">
        <div class="bx-modal__overlay" aria-hidden="true" phx-click="cancel_add" phx-target={@myself}></div>
        <div class="bx-modal__content" role="dialog" aria-modal="true">
          <h3 class="bx-subtitle"><%= gettext("Add a card") %></h3>
          <%!-- Stripe.js mounts its card element into this container --%>
          <div id={"#{@id}-card-element"} data-beeleex-card-element class="bx-card-element"></div>
          <p id={"#{@id}-card-errors"} data-beeleex-card-errors role="alert" class="bx-error"></p>
          <div class="bx-modal__actions">
            <.button variant="ghost" phx-click="cancel_add" phx-target={@myself}>
              <%= gettext("Cancel") %>
            </.button>
            <button type="button" id={"#{@id}-confirm-card"} data-beeleex-confirm-card class="bx-btn bx-btn--primary">
              <%= gettext("Save card") %>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- card display helpers -------------------------------------------------

  defp pm_tone("active"), do: :success
  defp pm_tone("deactivated"), do: :danger
  defp pm_tone(_), do: :neutral

  defp card(pm), do: pm[:stripe_card] || %{}
  defp card_brand(pm), do: card(pm)[:brand] || pm[:type] || "card"
  defp card_last4(pm), do: card(pm)[:last4] || "????"

  defp card_expiry(pm) do
    c = card(pm)

    case {c[:exp_month], c[:exp_year]} do
      {nil, _} -> "—"
      {month, year} -> "#{month}/#{year}"
    end
  end
end
