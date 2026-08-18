defmodule Beeleex.Converter do
  @moduledoc """
  Converts signed Beelee webhook payload objects into Beeleex event structs.
  """

  @spec convert_result(%{String.t() => any}) :: struct
  def convert_result(result) do
    struct(Beeleex.Event, convert_beelee_object(result))
  end

  defp convert_beelee_object(%{"type" => type_name} = value) do
    module = object_module(type_name)
    processed_result = ExGeeks.Helpers.atomize_keys(value)

    processed_result
    |> Map.merge(%{data: struct(module, processed_result.data.object)})
  end

  defp object_module("invoice_initiation"), do: Beeleex.InvoiceInitiation
  defp object_module("invoice_payment_success"), do: Beeleex.InvoicePayment
  defp object_module("invoice_payment_failure"), do: Beeleex.InvoicePayment
  defp object_module("payment_method_added"), do: Beeleex.PaymentMethod
  defp object_module("payment_method_add_failed"), do: Beeleex.PaymentMethod
  defp object_module("payment_method_expire_2M"), do: Beeleex.PaymentMethod
  defp object_module("payment_method_expire_1M"), do: Beeleex.PaymentMethod
  defp object_module("payment_method_update"), do: Beeleex.PaymentMethod
  defp object_module("payment_method_expiry_0_left"), do: Beeleex.PaymentMethod
  defp object_module("payment_method_expiry_1_left"), do: Beeleex.PaymentMethod
  defp object_module("company_update"), do: Beeleex.Company
end
