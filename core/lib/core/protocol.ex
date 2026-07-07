defmodule Core.Protocol do
  @moduledoc """
  Traduz os contratos do Core para mapas JSON-áveis (chaves string) e de volta.
  Único vocabulário compartilhado entre `server` e `firmware`. `decode/1` é
  tolerante: mensagem desconhecida vira `{:error, :unknown_message}`.
  """
  alias Core.Control.Command
  alias Core.Photo
  alias Core.Telemetry.Reading

  @version 1

  @spec version() :: pos_integer()
  def version, do: @version

  @spec encode(Reading.t() | Command.t() | Photo.t()) :: map()
  def encode(%Reading{} = r) do
    envelope("reading", %{
      "sensor_id" => r.sensor_id,
      "kind" => Atom.to_string(r.kind),
      "value" => r.value,
      "unit" => r.unit,
      "measured_at" => r.measured_at
    })
  end

  def encode(%Command{} = c) do
    envelope("command", %{
      "id" => c.id,
      "actuator_id" => c.actuator_id,
      "action" => Atom.to_string(c.action),
      "params" => c.params,
      "issued_at" => c.issued_at
    })
  end

  def encode(%Photo{} = p) do
    envelope("photo", %{
      "station_id" => p.station_id,
      "captured_at" => p.captured_at,
      "content_type" => p.content_type,
      "width" => p.width,
      "height" => p.height,
      "byte_size" => p.byte_size
    })
  end

  @spec decode(map()) :: {:ok, Reading.t() | Command.t() | Photo.t()} | {:error, :unknown_message}
  def decode(%{"v" => @version, "type" => "reading", "data" => d}) do
    {:ok,
     %Reading{
       sensor_id: d["sensor_id"],
       kind: String.to_existing_atom(d["kind"]),
       value: d["value"],
       unit: d["unit"],
       measured_at: d["measured_at"]
     }}
  end

  def decode(%{"v" => @version, "type" => "command", "data" => d}) do
    {:ok,
     %Command{
       id: d["id"],
       actuator_id: d["actuator_id"],
       action: String.to_existing_atom(d["action"]),
       params: d["params"] || %{},
       issued_at: d["issued_at"]
     }}
  end

  def decode(%{"v" => @version, "type" => "photo", "data" => d}) do
    {:ok,
     %Photo{
       station_id: d["station_id"],
       captured_at: d["captured_at"],
       content_type: d["content_type"],
       width: d["width"],
       height: d["height"],
       byte_size: d["byte_size"]
     }}
  end

  def decode(_other), do: {:error, :unknown_message}

  defp envelope(type, data), do: %{"v" => @version, "type" => type, "data" => data}
end
