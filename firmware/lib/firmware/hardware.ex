defmodule Firmware.Hardware do
  @moduledoc """
  Port de hardware (hexagonal). Adapters: `Firmware.Hardware.Circuits` (real, no Pi)
  e `Firmware.Hardware.Sim` (fake, no host). A escolha do adapter é injetada, nunca
  hard-coded — assim a malha fechada roda e é testada no Mac.
  """
  @callback read_sensor(sensor_id :: String.t(), kind :: atom()) ::
              {:ok, number()} | {:error, term()}
end
