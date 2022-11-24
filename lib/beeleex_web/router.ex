defmodule BeeleexWeb.Router do
  use BeeleexWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", BeeleexWeb do
    pipe_through :api
  end
end
