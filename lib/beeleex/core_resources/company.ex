defmodule Beeleex.Company do
  @moduledoc """
  Work with Beelee Company.
  """

  alias Beeleex.Helpers

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

  @spec compute_bu_cycle(Beeleex.Company.t()) :: Beeleex.Company.t()
  def compute_bu_cycle(
        %{business_unit: %{cycle: cycle_type, job: %{scheduled_at: next_execution_date}} = bu} =
          company
      ) do
    {:ok, date, _} = DateTime.from_iso8601(next_execution_date)

    bu =
      bu
      |> Map.merge(Helpers.compute_cycle_days(cycle_type, date))

    Map.put(company, :business_unit, bu)
  end
end
