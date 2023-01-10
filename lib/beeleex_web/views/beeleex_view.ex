defmodule BeeleexWeb.BeeleexView do
  @moduledoc false
  use BeeleexWeb, :view

  def render("user_verified.json", %{res: res}) do
    Map.take(res, [:user_id, :metadata, :fields])
  end

  def render("error.json", %{error: error}) do
    %{error: error}
  end
end
