# Token Verification

When Beelee needs to secure actions (e.g. when your users manage their
companies, payment methods, or browse invoices), it relays a token back to your
application for verification. Beeleex exposes a `POST /verify_token` endpoint
that bridges this to your own logic.

## Endpoint

Mounted by `use Beeleex.Routes` (see [configuration.md](configuration.md)):

```
POST <scope>/verify_token   →   BeeleexWeb.BeeleexController.verify_token
```

`Beeleex.Routes.__using__/1` defines two pipelines (`:beeleex_browser`,
`:beeleex_api`) and scopes the route through `:beeleex_api` plus any custom
pipes you pass.

## Request

```json
{
  "token": "the token",
  "fields": {
    "field_1": "value_1",
    "field_2": "value_2"
  }
}
```

- `token` — relayed from your app's original call to the Beelee API; verify it
  with your internal logic.
- `fields` — the profile fields Beelee wants resolved (commonly `name`,
  `email`).

## Your verifier callback

The controller looks up `config :beeleex, :verify_token_action` (required;
raises if missing) and calls `module.function(payload)`. It must return
`{:ok, result}` where `result` is a map with atom keys:

```elixir
result = %{
  user_id: "some user_id",
  fields: %{
    name: "some name",
    email: "some email"
  },
  metadata: %{                       # optional
    customer_projects: ["some id", "some other id"]
  }
}

{:ok, result}
```

| Key | Required | Purpose |
|-----|----------|---------|
| `user_id` | Yes | The user's ID in your application. |
| `fields` | Yes | Map of requested fields → values. |
| `metadata` | No | Extra information passed back to Beelee. |

## Responses

| Status | Body | Condition |
|--------|------|-----------|
| `200` | `user_verified.json` (renders `res`) | `{:ok, %{user_id:, fields:}}` returned **and** every requested field is present in `fields`. |
| `500` | `{"error": "missing requested field(s)"}` | A requested field is missing from the returned `fields`. |
| `400` | `{"error": "Invalid token"}` | The callback did not return a valid `{:ok, ...}` tuple. |

Rendering is handled by `BeeleexWeb.BeeleexView` (`user_verified.json` /
`error.json`).

> A Postman collection is shared at the project root for exercising the
> endpoint — import it and set the `url` environment variable to your app.
