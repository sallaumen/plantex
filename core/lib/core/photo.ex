defmodule Core.Photo do
  @moduledoc "Contrato de fio: metadados de uma foto capturada por um posto."

  @enforce_keys [:station_id, :captured_at, :content_type]
  defstruct [:station_id, :captured_at, :content_type, :width, :height, :byte_size]

  @type t :: %__MODULE__{
          station_id: String.t(),
          captured_at: integer(),
          content_type: String.t(),
          width: integer() | nil,
          height: integer() | nil,
          byte_size: integer() | nil
        }
end
