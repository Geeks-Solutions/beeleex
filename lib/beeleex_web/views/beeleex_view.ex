defmodule BeeleexWeb.BeeleexView do
  @moduledoc false
  use BeeleexWeb, :view

  def render("user_verified.json", %{user_id: user_id}) do
    %{
      user_id: user_id
    }
  end

  def render("error.json", %{error: error}) do
    %{error: error}
  end
end
