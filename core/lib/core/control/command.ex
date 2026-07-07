defmodule Core.Control.Command do
  @moduledoc "Contrato de fio: um comando enviado do server para um atuador."

  @enforce_keys [:id, :actuator_id, :action]
  defstruct [:id, :actuator_id, :action, {:params, %{}}, :issued_at]

  @type action :: :on | :off | :pulse

  @type t :: %__MODULE__{
          id: String.t(),
          actuator_id: String.t(),
          action: action(),
          params: map(),
          issued_at: integer() | nil
        }
end
