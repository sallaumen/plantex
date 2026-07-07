defmodule Core.Generators do
  @moduledoc "Geradores StreamData para os contratos do Core."
  import ExUnitProperties
  import StreamData
  alias Core.Control.Command
  alias Core.Photo
  alias Core.Telemetry.Reading

  def reading do
    gen all(
          sensor_id <- string(:printable),
          kind <- member_of([:air_temp, :air_humidity, :soil_moisture]),
          value <- one_of([integer(), float()]),
          unit <- one_of([constant(nil), string(:printable)]),
          measured_at <- integer(0..4_000_000_000_000)
        ) do
      %Reading{
        sensor_id: sensor_id,
        kind: kind,
        value: value,
        unit: unit,
        measured_at: measured_at
      }
    end
  end

  def command do
    gen all(
          id <- string(:printable),
          actuator_id <- string(:printable),
          action <- member_of([:on, :off, :pulse]),
          params <-
            map_of(
              string(:alphanumeric, min_length: 1),
              one_of([integer(), float(), boolean(), string(:alphanumeric)])
            ),
          issued_at <- integer(0..4_000_000_000_000)
        ) do
      %Command{
        id: id,
        actuator_id: actuator_id,
        action: action,
        params: params,
        issued_at: issued_at
      }
    end
  end

  def photo do
    gen all(
          station_id <- string(:printable),
          captured_at <- integer(0..4_000_000_000_000),
          content_type <- member_of(["image/jpeg", "image/png"]),
          width <- one_of([constant(nil), integer(1..10_000)]),
          height <- one_of([constant(nil), integer(1..10_000)]),
          byte_size <- one_of([constant(nil), integer(0..50_000_000)])
        ) do
      %Photo{
        station_id: station_id,
        captured_at: captured_at,
        content_type: content_type,
        width: width,
        height: height,
        byte_size: byte_size
      }
    end
  end
end
