defmodule Beeleex.Invoice do
  @moduledoc """
  A Beelee invoice. `tags` contains the original strings returned by Beelee.
  An empty tag list stays empty; missing or null tags are represented by `nil`.

  Money is in minor units with its stored scale. Integer scalars remain integers;
  BigInteger and Decimal strings remain exact strings, including `invoice_number`
  and `exchange_rate`. Unknown accounting facts remain `nil`, never zero.
  Seller/buyer snapshots are immutable legal facts; `company` is a live link.
  A complete invoice can be unnumbered. `closing_date` is settlement, not issuance.
  """

  @type amount :: integer() | String.t() | nil
  @type party_snapshot :: %{
          source_id: integer(),
          name: String.t(),
          address: map() | nil,
          vat_number: String.t() | nil,
          registration_number: String.t() | nil
        }
  @type usage_line :: %{
          name: String.t() | nil,
          description: String.t() | nil,
          quantity: integer() | nil,
          unit_price_before_tax: amount(),
          total_before_tax: amount(),
          tax: amount(),
          tax_rate: integer() | nil,
          total_with_tax: amount()
        }
  @type package_line :: %{
          project_id: String.t() | nil,
          project_name: String.t() | nil,
          package_name: String.t() | nil,
          package_description: String.t() | nil,
          package_price_before_tax: amount(),
          package_tax: amount(),
          package_tax_rate: integer() | nil,
          package_price_with_tax: amount(),
          pay_as_you_go: [usage_line()] | nil
        }

  @type t :: %__MODULE__{
          id: integer() | nil,
          invoice_number: amount(),
          invoice_reference: String.t() | nil,
          currency: String.t() | nil,
          amount_before_tax: amount(),
          tax_amount: amount(),
          tax_rate: integer() | nil,
          amount_with_tax: amount(),
          reduction_amount_before_tax: amount(),
          reduction_tax_amount: amount(),
          reduction_amount_with_tax: amount(),
          outstanding_amount: amount(),
          decimal_places: integer() | nil,
          issued_at: String.t() | nil,
          tax_point_date: String.t() | nil,
          due_date: String.t() | nil,
          accounting_data_status: String.t() | nil,
          seller_snapshot: party_snapshot() | nil,
          buyer_snapshot: party_snapshot() | nil,
          seller_currency: String.t() | nil,
          seller_decimal_places: integer() | nil,
          exchange_rate: String.t() | nil,
          seller_amount_before_tax: amount(),
          seller_tax_amount: amount(),
          seller_amount_with_tax: amount(),
          attempt: integer() | nil,
          cycle: integer() | nil,
          breakdown: [package_line()] | nil,
          beginning: String.t() | nil,
          end: String.t() | nil,
          closing_date: String.t() | nil,
          type: String.t() | nil,
          tags: [String.t()] | nil,
          company: map() | nil,
          status: String.t() | nil,
          inserted_at: String.t() | nil
        }

  # Mirror the flat public GraphQL contract without moving existing caller fields.
  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :invoice_number,
    :invoice_reference,
    :amount_before_tax,
    :tax_amount,
    :tax_rate,
    :amount_with_tax,
    :reduction_amount_before_tax,
    :reduction_tax_amount,
    :reduction_amount_with_tax,
    :outstanding_amount,
    :issued_at,
    :tax_point_date,
    :due_date,
    :accounting_data_status,
    :seller_snapshot,
    :buyer_snapshot,
    :seller_currency,
    :seller_decimal_places,
    :exchange_rate,
    :seller_amount_before_tax,
    :seller_tax_amount,
    :seller_amount_with_tax,
    :decimal_places,
    :attempt,
    :cycle,
    :breakdown,
    :beginning,
    :end,
    :closing_date,
    :type,
    :tags,
    :company,
    :status,
    :currency,
    :inserted_at
  ]
end
