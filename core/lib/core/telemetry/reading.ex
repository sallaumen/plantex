defmodule Core.Telemetry.Reading do
  @moduledoc "Contrato de fio: uma leitura de sensor emitida pelo firmware."

  @enforce_keys [:sensor_id, :kind, :value, :measured_at]
  defstruct [:sensor_id, :kind, :value, :unit, :measured_at]

  @type kind :: :air_temp | :air_humidity | :soil_moisture

  @type t :: %__MODULE__{
          sensor_id: String.t(),
          kind: kind(),
          value: number(),
          unit: String.t() | nil,
          measured_at: integer()
        }
end
