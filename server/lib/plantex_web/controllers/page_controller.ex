defmodule PlantexWeb.PageController do
  use PlantexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
