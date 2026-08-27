defmodule Beeleex.BusinessUnit do
  @moduledoc """
  The Beelee BusinessUnit struct.
  """

  @type nested_resource :: map() | nil

  @type t :: %__MODULE__{
          archived: boolean() | nil,
          billing_center: nested_resource(),
          current_cycle: nested_resource(),
          cycle: String.t() | nil,
          id: integer() | nil,
          invoices_count: integer() | nil,
          job: nested_resource(),
          name: String.t() | nil,
          secure_key: String.t() | nil,
          start_cycle_date: String.t() | nil,
          token_validation_url: String.t() | nil,
          verify_card_attachment: boolean() | nil,
          dev_mode: boolean() | nil,
          webhook_url: String.t() | nil
        }

  defstruct [
    :archived,
    :billing_center,
    :current_cycle,
    :cycle,
    :id,
    :invoices_count,
    :job,
    :name,
    :secure_key,
    :start_cycle_date,
    :token_validation_url,
    :verify_card_attachment,
    :dev_mode,
    :webhook_url
  ]
end
