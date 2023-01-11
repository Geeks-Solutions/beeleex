defmodule Beeleex do
  @moduledoc """
  Beeleex keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def json_library do
    Application.get_env(:beeleex, :json_library, Jason)
    |> expand_value()
  end

  defp expand_value({module, function, args})
      when is_atom(function) and is_list(args) do
    apply(module, function, args)
  end

  defp expand_value(value) when is_function(value) do
    value.()
  end

  defp expand_value(value), do: value
end
