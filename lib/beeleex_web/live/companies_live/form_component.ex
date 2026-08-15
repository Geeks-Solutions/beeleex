defmodule BeeleexWeb.CompaniesLive.FormComponent do
  @moduledoc """
  Create/edit form for a company. Uses a schemaless `Ecto.Changeset` for
  validation and submits through `Beeleex.Api.create_company/1` /
  `update_company/2`.
  """
  use BeeleexWeb, :live_component

  @fields %{
    name: :string,
    email: :string,
    phone_number: :string,
    vat_number: :string,
    registration_number: :string,
    city: :string,
    country: :string,
    postal_code: :string,
    street_name: :string,
    street_number: :string
  }

  @required [:name, :email]

  @impl true
  def update(%{company: company} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:error_message, fn -> nil end)
     |> assign_new(:form, fn -> to_form(changeset(company, %{}), as: :company) end)}
  end

  @impl true
  def handle_event("validate", %{"company" => params}, socket) do
    changeset = %{changeset(socket.assigns.company, params) | action: :validate}
    {:noreply, assign(socket, :form, to_form(changeset, as: :company))}
  end

  def handle_event("save", %{"company" => params}, socket) do
    changeset = changeset(socket.assigns.company, params)

    case Ecto.Changeset.apply_action(changeset, :save) do
      {:ok, data} ->
        save(socket, socket.assigns.action, data)

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :company))}
    end
  end

  defp save(socket, :new, data) do
    case socket.assigns.api_module.create_company(socket.assigns.bu_token, to_input(data)) do
      {:ok, company} -> notify(socket, company)
      {:error, message} -> {:noreply, assign(socket, :error_message, message)}
    end
  end

  defp save(socket, :edit, data) do
    case socket.assigns.api_module.update_company(
           socket.assigns.bu_token,
           socket.assigns.company.id,
           to_input(data)
         ) do
      {:ok, company} -> notify(socket, company)
      {:error, message} -> {:noreply, assign(socket, :error_message, message)}
    end
  end

  defp notify(socket, company) do
    send(self(), {:saved, company})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.flash_alert :if={@error_message} kind={:error}><%= @error_message %></.flash_alert>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} label={gettext("Company Name")} required />
        <.input field={@form[:email]} label={gettext("Email")} type="email" required />
        <.input field={@form[:phone_number]} label={gettext("Phone")} />
        <.input field={@form[:vat_number]} label={gettext("VAT number")} />
        <.input field={@form[:registration_number]} label={gettext("Registration number")} />

        <fieldset class="bx-fieldset">
          <legend><%= gettext("Address") %></legend>
          <.input field={@form[:street_number]} label={gettext("Street number")} />
          <.input field={@form[:street_name]} label={gettext("Street name")} />
          <.input field={@form[:postal_code]} label={gettext("Postal code")} />
          <.input field={@form[:city]} label={gettext("City")} />
          <.input field={@form[:country]} label={gettext("Country")} />
        </fieldset>

        <div class="bx-form-actions">
          <.button type="submit"><%= gettext("Save") %></.button>
          <.link navigate={@return_to} class="bx-btn bx-btn--ghost"><%= gettext("Cancel") %></.link>
        </div>
      </.form>
    </div>
    """
  end

  # --- changeset / mapping --------------------------------------------------

  defp changeset(company, params) do
    {defaults(company), @fields}
    |> Ecto.Changeset.cast(params, Map.keys(@fields))
    |> Ecto.Changeset.validate_required(@required)
    |> Ecto.Changeset.validate_format(:email, ~r/@/)
  end

  defp defaults(%Beeleex.Company{} = company) do
    address = company.address || %{}

    %{
      name: company.name,
      email: company.email,
      phone_number: company.phone_number,
      vat_number: company.vat_number,
      registration_number: company.registration_number,
      city: get(address, :city),
      country: get(address, :country),
      postal_code: get(address, :postal_code),
      street_name: get(address, :street_name),
      street_number: get(address, :street_number)
    }
  end

  defp get(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))

  # Build the camelCase Beelee `CompanyInput` payload.
  defp to_input(data) do
    %{
      name: data.name,
      email: data.email,
      phoneNumber: data.phone_number,
      vatNumber: data.vat_number,
      registrationNumber: data.registration_number,
      address: %{
        city: data.city,
        country: data.country,
        postalCode: data.postal_code,
        streetName: data.street_name,
        streetNumber: data.street_number
      }
    }
  end
end
