defmodule Beeleex.WebhookPlug do
  @moduledoc false

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
          handler: handler
        }
      ) do
    with {:ok, payload, _} <- Conn.read_body(conn),
         event <- Jason.decode!(payload),
         :ok <- handle_event!(handler, event) do
      send_resp(conn, 200, "") |> halt()
    else
      {:handle_error, reason} -> send_resp(conn, 400, reason) |> halt()
      _ -> send_resp(conn, 400, "") |> halt()
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
end
