defmodule Plantex.ProtocolBridgeTest do
  use ExUnit.Case, async: true

  test "decodifica uma mensagem de reading usando o Core" do
    wire =
      Core.Protocol.encode(%Core.Telemetry.Reading{
        sensor_id: "s1",
        kind: :air_temp,
        value: 22.0,
        measured_at: 0
      })

    assert {:ok, %Core.Telemetry.Reading{kind: :air_temp}} = Plantex.ProtocolBridge.ingest(wire)
  end

  test "mensagem inválida vira erro" do
    assert {:error, :unknown_message} = Plantex.ProtocolBridge.ingest(%{"nope" => true})
  end
end
