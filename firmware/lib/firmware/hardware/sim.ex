defmodule Firmware.Hardware.Sim do
  @moduledoc "Adapter de hardware simulado para desenvolvimento no host (sem Pi)."
  @behaviour Firmware.Hardware

  @impl Firmware.Hardware
  def read_sensor(_sensor_id, :air_temp), do: {:ok, 23.5}
  def read_sensor(_sensor_id, :air_humidity), do: {:ok, 55.0}
  def read_sensor(_sensor_id, :soil_moisture), do: {:ok, 42.0}
  def read_sensor(_sensor_id, _kind), do: {:error, :unsupported_kind}
end
