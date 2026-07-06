defmodule Core.Telemetry.ReadingTest do
  use ExUnit.Case, async: true
  alias Core.Telemetry.Reading

  test "constrói uma leitura válida" do
    r = %Reading{
      sensor_id: "s1",
      kind: :air_temp,
      value: 23.5,
      unit: "C",
      measured_at: 1_720_000_000_000
    }

    assert r.sensor_id == "s1"
    assert r.kind == :air_temp
    assert r.value == 23.5
    assert r.measured_at == 1_720_000_000_000
  end

  test "exige as chaves obrigatórias" do
    assert_raise ArgumentError, fn ->
      struct!(Reading, %{sensor_id: "s1"})
    end
  end
end
