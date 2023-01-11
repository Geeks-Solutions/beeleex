defmodule Beeleex.Company do
  @moduledoc """
  Work with Beelee Company.
  """

  @type t :: %__MODULE__{
          country: String.t(),
          projects_ids: list(String.t()),
          vat_number: String.t()
        }

  defstruct [
    :country,
    :projects_ids,
    :vat_number
  ]

end
