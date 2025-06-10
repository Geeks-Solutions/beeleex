defmodule Beeleex.Event do
  @moduledoc """
  Work with Beelee event objects.
  """

  @type event_data :: %{
          :object => event_data_object,
          optional(:previous_attributes) => map
        }

  @type event_data_object ::
          Beeleex.InvoiceInitiation.t()
          | Beeleex.InvoiceUpdate.t()
          | map

  @type t :: %__MODULE__{
          object: String.t(),
          api_version: String.t() | nil,
          created: String.t(),
          data: event_data,
          type: String.t()
        }

  defstruct [
    :object,
    :api_version,
    :created,
    :data,
    :type
  ]
end
