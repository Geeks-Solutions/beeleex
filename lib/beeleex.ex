defmodule Beeleex do
  @moduledoc """
  Beeleex keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  require Logger

  @doc """
  This function will log the variables passed if the debug_on variable is true
  this variable should be set in your environment.
  """
  def debug_variable(variable, label) do
    if Application.get_env(:beeleex, :debug_on, false) do
      Logger.configure(level: :debug)
      Logger.debug("#{label}: #{inspect(variable)}")
      Logger.configure(level: :info)
    end
  end
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
