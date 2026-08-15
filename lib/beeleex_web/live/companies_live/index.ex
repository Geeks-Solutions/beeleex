defmodule BeeleexWeb.CompaniesLive.Index do
  @moduledoc """
  Lists the Business Unit's companies. Data is fetched server-side via the
  injected API module.
  """
  use BeeleexWeb, :live_view

  @page_size 20

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Companies"),
       companies_path: "/companies",
       api_module: api_module(session),
       bu_token: BeeleexWeb.LiveSession.bu_token(session)
     )}
  end

  defp api_module(session), do: Map.get(session, "beeleex_api_module", Beeleex.Api)

  @impl true
  def handle_params(params, uri, socket) do
    page = to_int(params["page"], 1)
    q = params["q"]

    socket =
      socket
      |> assign(:companies_path, companies_base(uri))
      |> assign(:page, page)
      |> assign(:q, q)
      |> load_companies(page, q)

    {:noreply, socket}
  end

  # Skip the Beelee fetch during the static (disconnected) render — it would be
  # discarded and refetched on connect, and each fetch triggers a Beelee
  # `verify_token` callback. Assign empty state until the socket connects.
  defp load_companies(socket, page, q) do
    if connected?(socket) do
      fetch_companies(socket, page, q)
    else
      socket
      |> assign(:companies, [])
      |> assign(:total, 0)
      |> assign(:size, @page_size)
    end
  end

  defp fetch_companies(socket, page, q) do
    skip = (page - 1) * @page_size

    case socket.assigns.api_module.get_companies(socket.assigns.bu_token,
           filter: build_filter(q),
           size: @page_size,
           skip: skip
         ) do
      {:ok, %{companies: companies, total: total}} ->
        socket
        |> assign(:companies, companies)
        |> assign(:total, total)
        |> assign(:size, @page_size)

      {:error, message} ->
        socket
        |> assign(:companies, [])
        |> assign(:total, 0)
        |> assign(:size, @page_size)
        |> put_flash(:error, message)
    end
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: list_path(socket, 1, q))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bx-page">
      <div class="bx-header">
        <h1 class="bx-title"><%= gettext("Companies") %></h1>
        <.link navigate={@companies_path <> "/new"} class="bx-btn bx-btn--primary">
          <%= gettext("New company") %>
        </.link>
      </div>

      <form phx-submit="search" class="bx-search">
        <input type="text" name="q" value={@q} placeholder={gettext("Search by name")} class="bx-input" />
        <.button type="submit"><%= gettext("Search") %></.button>
      </form>

      <.table
        id="companies"
        rows={@companies}
        row_click={fn company -> JS.navigate(@companies_path <> "/#{company.id}") end}
        empty_message={gettext("No companies yet")}
      >
        <:col :let={company} label={gettext("Name")}><%= company.name %></:col>
        <:col :let={company} label={gettext("Email")}><%= company.email %></:col>
        <:col :let={company} label={gettext("VAT")}><%= company.vat_number %></:col>
        <:col :let={company} label={gettext("Solvency")}>
          <.badge tone={solvency_tone(company.solvency_status)}><%= company.solvency_status %></.badge>
        </:col>
        <:col :let={company} label={gettext("Invoices")}><%= company.invoices_count %></:col>
        <:action :let={company}>
          <.link navigate={@companies_path <> "/#{company.id}"} class="bx-action">
            <%= gettext("View") %>
          </.link>
        </:action>
      </.table>

      <.pagination
        page={@page}
        size={@size}
        total={@total}
        path={fn p -> list_path(@socket, p, @q) end}
      />
    </div>
    """
  end

  # --- helpers --------------------------------------------------------------

  defp list_path(socket, page, q) do
    base = socket.assigns[:companies_path] || "/companies"
    query = %{} |> maybe_put("page", page > 1 && page) |> maybe_put("q", q)
    if query == %{}, do: base, else: base <> "?" <> URI.encode_query(query)
  end

  defp maybe_put(map, _k, falsy) when falsy in [nil, false, ""], do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  # Best-effort name filter. Adjust to your Beelee `Filter` schema if needed.
  defp build_filter(nil), do: []
  defp build_filter(""), do: []
  defp build_filter(q), do: [%{key: "name", value: q}]

  defp to_int(nil, default), do: default

  defp to_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp companies_base(uri) do
    %URI{path: path} = URI.parse(uri)
    [head | _] = String.split(path, "/companies")
    head <> "/companies"
  end

  defp solvency_tone("solvent"), do: :success
  defp solvency_tone("at_risk"), do: :warning
  defp solvency_tone(status) when status in ["insolvent", "blocked"], do: :danger
  defp solvency_tone(_), do: :neutral
end
