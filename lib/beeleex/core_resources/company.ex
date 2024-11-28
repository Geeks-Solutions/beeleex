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
    solvency_status: String.t()
  }

  defstruct [
    :id,
    :user_id,
    :name,
    :email,
    :country,
    :projects_ids,
    :vat_number,
    :solvency_status
  ]

end
