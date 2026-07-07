defmodule Firmware.Hardware.SimTest do
  use ExUnit.Case, async: true
  alias Firmware.Hardware.Sim

  test "implementa o behaviour Hardware" do
    behaviours = Sim.module_info(:attributes)[:behaviour] || []
    assert Firmware.Hardware in behaviours
  end

  test "lê um valor plausível de temperatura do ar" do
    assert {:ok, value} = Sim.read_sensor("sensor-ar-1", :air_temp)
    assert is_number(value)
    assert value >= -10 and value <= 60
  end

  test "kind desconhecido retorna erro" do
    assert {:error, :unsupported_kind} = Sim.read_sensor("x", :banana)
  end
end
