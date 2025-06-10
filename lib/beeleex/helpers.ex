defmodule Beeleex.Helpers do
  @moduledoc false

  require Logger

  def env(key, default \\ nil) do
    Application.get_env(:beeleex, key)
    |> case do
      nil -> default
      value -> value
    end
  end
end
