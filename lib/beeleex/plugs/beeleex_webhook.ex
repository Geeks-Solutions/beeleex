defmodule Beeleex.WebhookPlug do
  @moduledoc """
  Helper `Plug` to process webhook events and send them to a custom handler.

  ## Installation

  To handle webhook events, you must first configure your application's endpoint.
  Add the following to `endpoint.ex`, **before** `Plug.Parsers` is loaded.

  ```elixir
  plug Beeleex.WebhookPlug,
    at: "/webhook/beeleex",
    handler: MyAppWeb.Billing.BeeleeHandler,
    secret: {Application, :get_env, [:beeleex, :business_unit_secure_key]}
  ```

  If you have not yet added a webhook to your Beelee account, you can do so
  by visiting `Business Unit` in the Beelee dashboard. Use the route
  you configured in the endpoint above and copy the secure key into your
  app's configuration.

  ### Supported options

  - `at`: The URL path your application should listen for Beelee webhooks on.
    Configure this to match whatever you set in the webhook.
  - `handler`: Custom event handler module that accepts `Beeleex.Event` structs
    and processes them within your application. You must create this module.
  - `secret`: Secure key obtained from the Beelee dashboard.
    This can also be a function or a tuple for runtime configuration.
  - `tolerance`: Maximum age (in seconds) allowed for the webhook event.

  ## Handling events

  You will need to create a custom event handler module to handle events.

  Your event handler module should define a `handle_event/1` function which takes
  a `Beeleex.Event` struct and returns either `{:ok, term}` or `:ok`.
  This will mark the event as successfully processed. Alternatively handler
  can signal an error by returning `:error` or `{:error, reason}` tuple,
  where reason is an atom or a string. HTTP status code 400 will be used for errors.

  ### Example

  ```elixir
  # lib/myapp_web/beelee_handler.ex

  defmodule MyAppWeb.BeeleeHandler do

    def handle_event(%Beeleex.Event{type: "invoice_initiation"} = event) do
      # TODO: handle the invoice_initiation event
    end

    def handle_event(%Beeleex.Event{type: "payment_method_added"} = event) do
      # TODO: handle the payment_method_added event
    end

    # Return HTTP 200 for unhandled events
    def handle_event(_event), do: :ok
  end
  ```

  ## Configuration

  You should configure the secure key in your app's own config file.
  For example:

  ```elixir
  config :beeleex,
    # [...]
    business_unit_secure_key: "whsec_******"
  ```

  You may then include the secret in your endpoint:

  ```elixir
  plug Beeleex.WebhookPlug,
    at: "/webhook/beeleex",
    handler: MyAppWeb.Billing.BeeleeHandler,
    secret: Application.get_env(:beeleex, :business_unit_secure_key)
  ```

  ### Runtime configuration

  If you're loading config dynamically at runtime (eg with `runtime.exs`
  or an OTP app) you must pass a tuple or function as the secret.

  ```elixir
  # With a tuple
  plug Beeleex.WebhookPlug,
    at: "/webhook/Beeleex",
    handler: MyAppWeb.Billing.BeeleeHandler,
    secret: {Application, :get_env, [:beeleex, :business_unit_secure_key]}

  # Or, with a function
  plug Beeleex.WebhookPlug,
    at: "/webhook/beeleex",
    handler: MyAppWeb.Billing.BeeleeHandler,
    secret: fn -> Application.get_env(:beeleex, :business_unit_secure_key) end
  ```
  """

  alias Beeleex.Webhook
  import Plug.Conn
  alias Plug.Conn
  @behaviour Plug

  @impl true
  def init(opts) do
    path_info = String.split(opts[:at], "/", trim: true)

    opts
    |> Enum.into(%{})
    |> Map.put_new(:path_info, path_info)
  end

  @impl true
  def call(
        %Conn{method: "POST", path_info: path_info} = conn,
        %{
          path_info: path_info,
          secret: secret,
          handler: handler
        } = opts
      ) do
    secret = parse_secret!(secret)

    with [signature] <- get_req_header(conn, "beelee-signature"),
         {:ok, payload, _} <- Conn.read_body(conn),
         {:ok, event} <- construct_event(payload, signature, secret, opts),
         :ok <- handle_event!(handler, event) do
      send_resp(conn, 200, "") |> halt()
    else
      {:handle_error, reason} ->
        send_resp(conn, 400, reason) |> halt()
      [] ->
        send_resp(conn, 400, "Secure your call with a valid signature and try again") |> halt()
      {:error, error} ->
        send_resp(conn, 400, error) |> halt()
      error ->
        send_resp(conn, 400, "error: #{error}") |> halt()
    end
  end

  @impl true
  def call(%Conn{path_info: path_info} = conn, %{path_info: path_info}) do
    send_resp(conn, 400, "") |> halt()
  end

  @impl true
  def call(conn, _), do: conn

  defp handle_event!(handler, event) do
    case handler.handle_event(event) do
      {:ok, _} ->
        :ok

      :ok ->
        :ok

      {:error, reason} when is_binary(reason) ->
        {:handle_error, reason}

      {:error, reason} when is_atom(reason) ->
        {:handle_error, Atom.to_string(reason)}

      :error ->
        {:handle_error, ""}

      resp ->
        raise """
        #{inspect(handler)}.handle_event/1 returned an invalid response. Expected {:ok, term}, :ok, {:error, reason} or :error
        Got: #{inspect(resp)}

        Event data: #{inspect(event)}
        """
    end
  end

  defp construct_event(payload, signature, secret, %{tolerance: tolerance}) do
    Webhook.construct_event(payload, signature, secret, tolerance)
  end

  defp construct_event(payload, signature, secret, _opts) do
    Webhook.construct_event(payload, signature, secret)
  end

  defp parse_secret!({m, f, a}), do: apply(m, f, a)
  defp parse_secret!(fun) when is_function(fun), do: fun.()
  defp parse_secret!(secret) when is_binary(secret), do: secret

  defp parse_secret!(secret) do
    raise """
    The Beelee webhook secret is invalid. Expected a string, tuple, or function.
    Got: #{inspect(secret)}
    If you're setting the secret at runtime, you need to pass a tuple or function.
    For example:
    plug Beeleex.WebhookPlug,
      at: "/webhook/beeleex",
      handler: MyAppWeb.BeeleeHandler,
      secret: {Application, :get_env, [:myapp, :beelee_bu_secure_secret]}
    """
  end
end
