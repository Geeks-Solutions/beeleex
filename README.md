# Beeleex

Beeleex is a helper library that allows you to quickly setup the connections between your business unit and BeeLee.
## Installation

  In your mix.exs add this to your list of dependencies:

  ```elixir
  {:beeleex, "~> 0.1.0"}
  ```
## Configuration
### Common Configuration
To setup Beeleex in a phoenix application, all you need to do is the following (feel free to contribute for other frameworks):

  - In your `router.ex`, add this line:
  ```elixir
  use Beeleex.Routes, scope: "/beeleex"
  ```
  You can customize the scope and provide the options of your choice to adjust this to your application need.

This provides a standard route to let Beelee verify tokens provided by your application when you are allowing your users to manage their companies, payment methods and browse their invoices.

Then in your `endpoint.ex` add a plug to properly handle webhooks:
```elixir
plug Beeleex.WebhookPlug,
    at: "/api/webhook/beeleex", # adjust to your choice
    secret: {Application, :get_env, [:beeleex, :business_unit_secure_key]},
    handler: MyApp.BeeleeHandler
```

The `BeeleeHandler` module needs to implement the `handle_event/1` callback. For more details refer to the `Beeleex.WebhookPlug` module documentation.

  - In your `config.ex`, add the following: 
  ```elixir
  config :beeleex,
  verify_token_action: %{module: YourModule, function: :function_name}
  business_unit_secure_key: "your bu secure key",
  business_unit_id: "your bu_id"
  ```

You could also set the `debug_on` to true in your config if you would like to introspect all events sent to your Business Unit.

## Usage
### Token Verification
When beelee needs to secure actions, it will relay the token verification to your application, the token verifier handler will receive one payload map as a param, the map will contain two keys: `token` and `fields`

The `token` is relayed from your application call to Beelee API so you can verify it with your internal logic
The `fields` is a list that will contain the `name` and `email` entries

The callback should return an {:ok, result} tuple with result being a map with the following atom keys:
- `user_id`: the user_id in your application
- `metadata`: an optional map with extra informations
- `fields`: a map with the requested fields and their value from your application

```elixir
result = %{
  user_id: "some user_id",
  fields: %{
    name: "some name",
    email: "some email"
  },
  metadata: %{
    customer_projects: ["some id", "some other id"]
  }
}

{:ok, result}
```

### Events
Beelee communicates with your Business Units through webhooks, all events will be relayed to your Handler module as configured above.

The `handle_event/1` callback will receive an `%Beeleex.Event{}` struct. Refer to the struct documentation for more details.

You are free to implement the callback for any event you would like your application to support.

Here is a list of events sent by Beelee with a short description of when this event occurs:
- `invoice_initiation`: A new cycle runs and invoices were generated for this cycle.
- `invoice_payment_succeeded`: An invoice has been successfully paid.
- `invoice_payment_failed`: An invoice payment attempt failed.
- `payment_method_added`: A new payment method was added to a company.
- `payment_method_add_failed`: An attempt to add a new payment method to a company failed.
- `payment_method_expire_2M`: A payment method is set to expire in 2 months.
- `payment_method_expire_1M`: A payment method is set to expire in 1 month.
- `payment_method_update`: A payment method has been updated.
- `payment_method_expiry_1_left`: A payment method expired and there is only one valid method left in the company.
- `payment_method_expiry_0_left`: The last payment method for this company expired.
- `company_update`: The company has been updated by the system (e.g becomes insolvent on payment failures or payment method expiration).

### API calls
To simplify regular calls to Beelee API the `Beeleex.Api` module expose a set of functions you can call to automate your billing management.

See the module's documentation for a full list of supported functions.