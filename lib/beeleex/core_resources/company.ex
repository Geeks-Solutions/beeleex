defmodule Beeleex.Company do
  @moduledoc """
  Work with Beelee Company.
  """

  @type t :: %__MODULE__{
          id: integer,
          user_id: String.t(),
          name: String.t(),
          email: String.t(),
          country: String.t(),
          projects_ids: list(String.t()),
          vat_number: String.t(),
          solvency_status: String.t(),
          unlinked_project_id: String.t(),
          phone_number: String.t(),
          address: map(),
          business_unit: map()
        }

  defstruct [
    :id,
    :user_id,
    :name,
    :email,
    :country,
    :projects_ids,
    :vat_number,
    :solvency_status,
    :unlinked_project_id,
    :phone_number,
    :address,
    :business_unit
  ]
end
