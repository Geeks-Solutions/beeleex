defmodule Beeleex.ApiBehaviour do
  @moduledoc """
  Behaviour for the subset of `Beeleex.Api` used by the LiveView pages.

  The LiveViews use `Beeleex.Api` by default. Tests and local harnesses can pass
  another module with `use Beeleex.Routes, api_module: MyApi`, as long as it
  implements this behaviour.
  """

  alias Beeleex.Company
  alias Beeleex.Invoice

  @typedoc "The signed-in end user's `user_portal` token, sent as `bu-authorization`."
  @type token :: String.t()

  @callback get_companies(token, keyword) ::
              {:ok, %{companies: list(Company.t()), total: integer, count: integer}}
              | {:error, String.t()}
  @callback get_company(token, integer | String.t()) ::
              {:ok, Company.t()} | {:error, String.t()}
  @callback create_company(token, map) :: {:ok, Company.t()} | {:error, String.t()}
  @callback update_company(token, integer | String.t(), map) ::
              {:ok, Company.t()} | {:error, String.t()}
  @callback delete_company(token, integer | String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
  @callback get_unlinked_projects(token, list(String.t())) ::
              {:ok, list(String.t())} | {:error, String.t()}
  @callback link_projects(token, integer | String.t(), list) ::
              {:ok, Company.t()} | {:error, String.t()}
  @callback unlink_project(token, integer | String.t(), any) ::
              {:ok, Company.t()} | {:error, String.t()}

  @callback get_invoices(token, keyword) ::
              {:ok, %{invoices: list(Invoice.t()), total: integer, count: integer}}
              | {:error, String.t()}
  @callback get_invoice(token, integer | String.t()) :: {:ok, Invoice.t()} | {:error, String.t()}

  @callback get_payment_methods(token, keyword) ::
              {:ok, %{payment_methods: list(map), total: integer, count: integer}}
              | {:error, String.t()}
  @callback request_setup_intent(token, integer | String.t()) ::
              {:ok, %{client_secret: String.t(), publishable_key: String.t(), verified: boolean}}
              | {:error, String.t()}
  @callback deactivate_payment_method(token, integer | String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
  @callback reactivate_payment_method(token, integer | String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
  @callback make_default_payment_method(token, integer | String.t(), integer | String.t()) ::
              {:ok, String.t()} | {:error, String.t()}
end
