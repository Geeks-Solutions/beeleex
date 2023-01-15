defmodule Beeleex.Company do
  @moduledoc """
  Work with Beelee Company.
  """

  @type t :: %__MODULE__{
      id: integer,
      country: String.t(),
      projects_ids: list(String.t()),
      vat_number: String.t()
        }

  defstruct [
    :id,
    :country,
    :projects_ids,
    :vat_number
  ]

end
