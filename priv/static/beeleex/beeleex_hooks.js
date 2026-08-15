/**
 * Beeleex LiveView JavaScript hooks.
 *
 * Ship these hooks to your LiveSocket so the Beeleex billing pages can drive the
 * client-side Stripe flow used to add a payment method.
 *
 * Usage (in your app.js):
 *
 *   import { BeeleexHooks } from "../../deps/beeleex/priv/static/beeleex/beeleex_hooks.js"
 *
 *   const liveSocket = new LiveSocket("/live", Socket, {
 *     params: { _csrf_token: csrfToken },
 *     hooks: { ...BeeleexHooks }
 *   })
 *
 * The `BeeleexStripeSetup` hook listens for a "beeleex:init_stripe" event pushed
 * by the payment-methods component, loads Stripe.js on demand, mounts a card
 * element, and on confirmation calls stripe.confirmCardSetup(). On success it
 * pushes "payment_method_added" back to the component so the list refreshes.
 */

const STRIPE_JS_URL = "https://js.stripe.com/v3";

function loadStripeJs() {
  return new Promise((resolve, reject) => {
    if (window.Stripe) {
      resolve(window.Stripe);
      return;
    }

    const existing = document.querySelector(`script[src="${STRIPE_JS_URL}"]`);
    if (existing) {
      existing.addEventListener("load", () => resolve(window.Stripe));
      existing.addEventListener("error", reject);
      return;
    }

    const script = document.createElement("script");
    script.src = STRIPE_JS_URL;
    script.onload = () => resolve(window.Stripe);
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

const BeeleexStripeSetup = {
  mounted() {
    this.stripe = null;
    this.card = null;
    this.clientSecret = null;

    this.handleEvent("beeleex:init_stripe", (payload) => {
      // Only react to events targeted at this component instance.
      if (payload.target && payload.target !== `#${this.el.id}`) return;
      this.initStripe(payload);
    });
  },

  destroyed() {
    if (this.card) this.card.unmount();
  },

  async initStripe({ client_secret, publishable_key }) {
    this.clientSecret = client_secret;

    try {
      const Stripe = await loadStripeJs();
      this.stripe = Stripe(publishable_key);
    } catch (_error) {
      this.setError("Could not load Stripe.js");
      return;
    }

    // Wait a tick so the (now visible) modal container is in the DOM.
    requestAnimationFrame(() => this.mountCard());
  },

  mountCard() {
    const container = this.el.querySelector("[data-beeleex-card-element]");
    const confirmButton = this.el.querySelector("[data-beeleex-confirm-card]");
    if (!container || !confirmButton) return;

    if (!this.stripe) {
      this.setError("Stripe could not be initialized. Check the publishable key.");
      return;
    }

    // Re-opening the modal creates a fresh container, so tear down any element
    // from a previous open before mounting a new one.
    if (this.card) this.card.unmount();

    try {
      const elements = this.stripe.elements();
      this.card = elements.create("card");
      this.card.mount(container);
    } catch (error) {
      this.setError((error && error.message) || "Could not display the card form.");
      return;
    }

    this.card.on("change", (event) => this.setError(event.error ? event.error.message : ""));

    // Avoid stacking duplicate click handlers across re-opens.
    if (this.confirmHandler) confirmButton.removeEventListener("click", this.confirmHandler);
    this.confirmHandler = () => this.confirmCard(confirmButton);
    confirmButton.addEventListener("click", this.confirmHandler);
  },

  async confirmCard(confirmButton) {
    console.log("[beeleex] confirmCard clicked", {
      hasStripe: !!this.stripe,
      hasClientSecret: !!this.clientSecret,
      clientSecret: this.clientSecret
    });

    if (!this.stripe || !this.clientSecret) {
      console.warn("[beeleex] confirmCard aborted: stripe or clientSecret missing");
      return;
    }
    confirmButton.disabled = true;

    const result = await this.stripe.confirmCardSetup(this.clientSecret, {
      payment_method: {
        card: this.card,
        // Stripe metadata values must be strings.
        metadata: { beelee: "true" }
      }
    });

    confirmButton.disabled = false;

    console.log("[beeleex] confirmCardSetup result", {
      error: result.error,
      status: result.setupIntent && result.setupIntent.status,
      payment_method: result.setupIntent && result.setupIntent.payment_method
    });

    if (result.error) {
      console.error("[beeleex] confirmCardSetup error:", result.error.message);
      this.setError(result.error.message);
      return;
    }

    if (result.setupIntent && result.setupIntent.status === "succeeded") {
      this.setError("");
      console.log("[beeleex] pushing payment_method_added ->", result.setupIntent.payment_method);
      // Notify the owning LiveComponent so it can refresh its list.
      this.pushEventTo(this.el, "payment_method_added", {
        payment_method: result.setupIntent.payment_method
      });
    } else {
      console.warn(
        "[beeleex] setupIntent did not succeed; status =",
        result.setupIntent && result.setupIntent.status
      );
    }
  },

  setError(message) {
    const node = this.el.querySelector("[data-beeleex-card-errors]");
    if (node) node.textContent = message || "";
  }
};

export const BeeleexHooks = { BeeleexStripeSetup };
export default BeeleexHooks;
