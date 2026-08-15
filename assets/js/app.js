// Entry point for the bundled Beeleex dev endpoint.
//
// This wires up the LiveView client plus the Beeleex Stripe hook so the demo
// pages are fully interactive. Host applications have their own app.js; they
// only need to merge in BeeleexHooks (see docs/integration/payment-methods.md).
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { BeeleexHooks } from "../../priv/static/beeleex/beeleex_hooks.js"

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content")

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { ...BeeleexHooks }
})

liveSocket.connect()
window.liveSocket = liveSocket
