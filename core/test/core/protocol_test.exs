defmodule Core.ProtocolTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Core.Control.Command
  alias Core.Protocol
  alias Core.Telemetry.Reading

  test "encode marca versão e tipo" do
    r = %Reading{sensor_id: "s1", kind: :air_temp, value: 1, measured_at: 0}
    encoded = Protocol.encode(r)
    assert encoded["v"] == Protocol.version()
    assert encoded["type"] == "reading"
  end

  test "decode de mensagem desconhecida" do
    assert Protocol.decode(%{"v" => 999, "type" => "nope"}) == {:error, :unknown_message}
  end

  property "round-trip de Reading" do
    check all(r <- Core.Generators.reading()) do
      assert Protocol.decode(Protocol.encode(r)) == {:ok, r}
    end
  end

  property "round-trip de Command" do
    check all(c <- Core.Generators.command()) do
      assert Protocol.decode(Protocol.encode(c)) == {:ok, c}
    end
  end

  property "round-trip de Photo" do
    check all(p <- Core.Generators.photo()) do
      assert Protocol.decode(Protocol.encode(p)) == {:ok, p}
    end
  end

  test "actions e kinds sobrevivem ao fio como átomos" do
    c = %Command{id: "c", actuator_id: "a", action: :pulse, params: %{}}
    assert {:ok, %Command{action: :pulse}} = Protocol.decode(Protocol.encode(c))
  end
end
