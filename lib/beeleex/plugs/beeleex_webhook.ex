defmodule Beeleex.WebhookPlug do
  @moduledoc false

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
        }
      ) do
    secret = parse_secret!(secret)

    with [signature] <- get_req_header(conn, "beelee-signature"),
         {:ok, payload, _} <- Conn.read_body(conn),
         {:ok, event} <- Webhook.construct_event(payload, signature, secret),
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
