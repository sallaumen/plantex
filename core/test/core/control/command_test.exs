defmodule Core.Control.CommandTest do
  use ExUnit.Case, async: true
  alias Core.Control.Command

  test "constrói um comando de pulso" do
    c = %Command{
      id: "c1",
      actuator_id: "a1",
      action: :pulse,
      params: %{"ms" => 5000},
      issued_at: 1_720_000_000_000
    }

    assert c.action == :pulse
    assert c.params == %{"ms" => 5000}
  end

  test "params default é mapa vazio" do
    c = %Command{id: "c1", actuator_id: "a1", action: :off}
    assert c.params == %{}
  end
end
