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

  # Beelee attaches the card and then verifies it with a small authorization.
  # Keep reloading for up to five seconds while we wait for it to appear in the
  # payment method list.
  @verification_retries_ms [1000, 1000, 1000, 1000, 1000]
  @verification_flash_ttl_ms 2_500

  @impl true
  # Re-check after adding a card: reload, and if the new method still isn't
  # visible, schedule the next attempt. Driven by `send_update/3` from a task.
  def update(%{verify_payment_method: {stripe_payment_method_id, before_count, rest}}, socket) do
    socket = load(socket)
    now_count = length(socket.assigns.payment_methods)

    Logger.info(
      "[beeleex] payment_methods verify-if-added id=#{socket.assigns.id} " <>
        "target=#{inspect(stripe_payment_method_id)} " <>
        "before=#{before_count} now=#{now_count} remaining_attempts=#{length(rest)}"
    )

    if payment_method_present?(
         socket.assigns.payment_methods,
         stripe_payment_method_id,
         before_count
       ) do
      {:ok,
       socket
       |> assign(
         notice: gettext("Payment method added successfully"),
         notice_clear_token: nil,
         verification_payment_method_id: nil,
         verification_before_count: 0
       )
       |> schedule_notice_clear()}
    else
      case rest do
        [] ->
          {:ok,
           socket
           |> clear_verification()
           |> assign(
             error:
               gettext(
                 "The card could not be verified. Please make sure this card has enough funds and try again."
               )
           )}

        _ ->
          schedule_verification_reload(
            self(),
            socket.assigns.id,
            stripe_payment_method_id,
            before_count,
            rest
          )

          {:ok, socket}
      end
    end
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      socket
      |> assign_new(:adding, fn -> false end)
      |> assign_new(:error, fn -> nil end)
      |> assign_new(:notice, fn -> nil end)
      |> assign_new(:form_status, fn -> nil end)
      |> assign_new(:verification_payment_method_id, fn -> nil end)
      |> assign_new(:verification_before_count, fn -> 0 end)
      |> assign_new(:notice_clear_token, fn -> nil end)

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

  # Schedule the next verification refresh attempt from a detached task. `send_update/3`
  # can target the LiveComponent from any process, so this needs no `handle_info` in
  # the host page. Stops once `rest` is exhausted.
  defp schedule_verification_reload(_lv_pid, _id, _stripe_payment_method_id, _before_count, []),
    do: :ok

  defp schedule_verification_reload(
         lv_pid,
         id,
         stripe_payment_method_id,
         before_count,
         [delay | rest]
       ) do
    Task.start(fn ->
      Process.sleep(delay)

      Phoenix.LiveView.send_update(lv_pid, __MODULE__,
        id: id,
        verify_payment_method: {stripe_payment_method_id, before_count, rest}
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
         |> assign(
           adding: true,
           error: nil,
           notice: nil,
           form_status: gettext("Preparing card form"),
           verification_payment_method_id: nil,
           verification_before_count: 0
         )
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

        {:noreply,
         socket
         |> assign(
           error: message,
           notice: nil,
           form_status: nil,
           verification_payment_method_id: nil,
           verification_before_count: 0,
           notice_clear_token: nil
         )}
    end
  end

  def handle_event("cancel_add", _params, socket) do
    {:noreply, assign(socket, adding: false, form_status: nil)}
  end

  def handle_event("payment_method_added", params, socket) do
    Logger.info(
      "[beeleex] payment_method_added event received id=#{socket.assigns.id} " <>
        "company_id=#{socket.assigns.company_id} params=#{inspect(params)}"
    )

    send(self(), {:payment_methods_updated, socket.assigns.company_id})

    stripe_payment_method_id = normalize_payment_method_id(params["payment_method"])
    before_count = length(socket.assigns.payment_methods)

    socket =
      socket
      |> assign(
        adding: false,
        form_status: nil,
        error: nil,
        notice: gettext("Card attached and is being verified with a 1 EUR authorization..."),
        verification_payment_method_id: stripe_payment_method_id,
        verification_before_count: before_count
      )
      |> load()

    if payment_method_present?(
         socket.assigns.payment_methods,
         stripe_payment_method_id,
         before_count
       ) do
      {:noreply,
       socket
       |> clear_verification()
       |> assign(notice: gettext("Payment method added successfully"))
       |> schedule_notice_clear()}
    else
      schedule_verification_reload(
        self(),
        socket.assigns.id,
        stripe_payment_method_id,
        before_count,
        @verification_retries_ms
      )

      {:noreply, socket}
    end
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

  def handle_info({:clear_notice, token}, socket) do
    if socket.assigns.notice_clear_token == token do
      {:noreply, assign(socket, notice: nil, notice_clear_token: nil)}
    else
      {:noreply, socket}
    end
  end

  defp clear_verification(socket) do
    assign(socket,
      notice: nil,
      verification_payment_method_id: nil,
      verification_before_count: 0,
      notice_clear_token: nil
    )
  end

  defp payment_method_present?(methods, nil, before_count) do
    length(methods) > before_count
  end

  defp payment_method_present?(methods, stripe_payment_method_id, before_count) do
    normalized_id = normalize_payment_method_id(stripe_payment_method_id)

    Enum.any?(methods, &payment_method_has_stripe_id?(&1, normalized_id)) or
      length(methods) > before_count
  end

  defp payment_method_has_stripe_id?(method, stripe_payment_method_id) do
    normalize_payment_method_id(method_stripe_id(method)) == stripe_payment_method_id
  end

  defp method_stripe_id(method) do
    stripe_card = method[:stripe_card] || %{}
    stripe_card[:stripe_id] || stripe_card[:stripeId] || method[:stripe_id] || method[:stripeId]
  end

  defp normalize_payment_method_id(nil), do: nil
  defp normalize_payment_method_id(value) when is_binary(value), do: value
  defp normalize_payment_method_id(value) when is_integer(value), do: Integer.to_string(value)

  defp normalize_payment_method_id(%{} = value) do
    value[:id] || value["id"]
  end

  defp normalize_payment_method_id(value), do: to_string(value)

  defp schedule_notice_clear(socket) do
    token = make_ref()
    Process.send_after(self(), {:clear_notice, token}, @verification_flash_ttl_ms)

    assign(socket, notice_clear_token: token)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} phx-hook="BeeleexStripeSetup" phx-target={@myself} class="beeleex-payment-methods">
      <.flash_alert :if={@error} kind={:error}><%= @error %></.flash_alert>
      <.flash_alert :if={@notice} kind={:info}>
        <span class={@verification_payment_method_id && "bx-inline-feedback"}>
          <span :if={@verification_payment_method_id} class="bx-spinner bx-spinner--info" aria-hidden="true"></span>
          <%= @notice %>
        </span>
      </.flash_alert>

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
        phx-disable-with={gettext("Preparing card form")}
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
          <p
            :if={@form_status}
            id={"#{@id}-card-status"}
            data-beeleex-card-status
            role="status"
            aria-live="polite"
            class="bx-muted"
          >
            <%= @form_status %>
          </p>
          <div class="bx-modal__actions">
            <.button variant="ghost" phx-click="cancel_add" phx-target={@myself}>
              <%= gettext("Cancel") %>
            </.button>
            <button
              type="button"
              id={"#{@id}-confirm-card"}
              data-beeleex-confirm-card
              data-beeleex-confirm-label={gettext("Save card")}
              data-beeleex-validating-label={gettext("Validating card...")}
              phx-target={@myself}
              class="bx-btn bx-btn--primary"
            >
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
