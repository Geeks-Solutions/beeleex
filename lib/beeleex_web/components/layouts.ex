defmodule BeeleexWeb.Layouts do
  @moduledoc """
  Layouts used by the bundled Beeleex dev endpoint and as a sensible default
  when a host application mounts the Beeleex LiveView pages without supplying
  its own layout.

  Host applications that already have their own root layout can pass
  `root_layout:` / `layout:` options when mounting the pages and these will be
  used instead.
  """
  use BeeleexWeb, :html

  @doc """
  The root (full HTML document) layout. Used by the bundled dev endpoint.
  """
  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title><%= assigns[:page_title] || "Beelee Billing" %></title>
        <link phx-track-static rel="stylesheet" href="/beeleex/beeleex.css" />
        <script defer type="text/javascript" src="/assets/app.js">
        </script>
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  @doc """
  The inner ("app") layout wrapping every Beeleex LiveView. Renders flash
  messages and the page content.
  """
  def live(assigns) do
    ~H"""
    <main class="beeleex">
      <.flash_alert :if={Phoenix.Flash.get(@flash, :info)} kind={:info} flash={@flash} />
      <.flash_alert :if={Phoenix.Flash.get(@flash, :error)} kind={:error} flash={@flash} />
      <%= @inner_content %>
    </main>
    """
  end
end
