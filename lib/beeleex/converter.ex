defmodule Beeleex.Converter do
@moduledoc """
This module handles converting the data received by Beelee API and by the host project
to a standard format
"""

  @spec convert_result(%{String.t() => any}) :: struct
  def convert_result(result) do
    convert_beelee_object(result)
  end

  defp convert_beelee_object(%{"object" => object_name} = value) do
    module = object_module(object_name)
    processed_result = ExGeeks.Helpers.atomize_keys(value)
    processed_result
    |> Map.merge(%{data: struct(module, processed_result.data.object)})
  end

  defp object_module("InvoiceInitiation"), do: Beeleex.InvoiceInitiation
  defp object_module("InvoiceUpdate"), do: Beeleex.InvoiceUpdate
end
