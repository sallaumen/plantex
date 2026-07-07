defmodule Plantex.ProtocolBridge do
  @moduledoc """
  Fronteira fina entre o transporte (Channel) e os contratos do `Core`.
  Nas fases seguintes, delega o resultado decodificado aos contexts
  (`Telemetry.ingest/1`, `Vision.store_photo/1`, ...).
  """
  @spec ingest(map()) :: {:ok, struct()} | {:error, :unknown_message}
  defdelegate ingest(message), to: Core.Protocol, as: :decode
end
