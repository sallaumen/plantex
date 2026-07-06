# Plantex — Fase 0: Fundação Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Estabelecer o monorepo poncho do Plantex — o app de contratos `core/` completo e testado, os scaffolds `server/` (Phoenix) e `firmware/` (Nerves) ligados ao `core` por `path:`, e CI verde — como base sem hardware para todas as fases seguintes.

**Architecture:** Poncho project (apps irmãos ligados por `path:`, sem `mix.exs` raiz). `core/` é Elixir puro (contratos do fio, sem Phoenix/Nerves). `server/` é Phoenix+Postgres (o cérebro). `firmware/` é Nerves target `rpi3`+`host` (o braço). Só o `core/` é compartilhado.

**Tech Stack:** Elixir 1.19.5-otp-27 / Erlang 27.3.4.11 · Phoenix 1.8.8 · Nerves (`nerves_system_rpi3`) · stream_data (property tests) · credo/dialyxir/ex_check (`mix check`) · GitHub Actions.

## Global Constraints

- **Toolchain:** Elixir `1.19.5-otp-27`, Erlang `27.3.4.11` (`.tool-versions` em cada app).
- **Poncho, não umbrella:** sem `mix.exs` na raiz; deps internas via `path:`. `core/` **não pode** ter deps de Phoenix nem Nerves.
- **Nomes de app/módulo:** `core/` → app `:core`, módulo `Core`. `server/` → app `:plantex`, módulo `Plantex`/`PlantexWeb`. `firmware/` → app `:firmware`, módulo `Firmware`.
- **Conteúdo:** cultivo genérico, **zero apologia a drogas**, exemplo canônico **tomate-cereja** em qualquer seed/fixture/doc.
- **Gate de qualidade:** `mix check` (compile `-Werror`, `format`, `credo --strict`, `dialyzer`, unused deps) verde em cada app; `sobelow` no `server/`.
- **Wire = mapas JSON-áveis:** `Core.Protocol` converte struct ↔ mapa de chaves string. `measured_at`/timestamps no fio são **inteiros unix em milissegundos** (round-trip exato); o `server` converte para `DateTime` ao persistir.
- **Pré-requisitos de ambiente (instalar antes da Task 7/8):** `mix archive.install hex phx_new 1.8.8`, `mix archive.install hex nerves_bootstrap`. Build de firmware `rpi3` exige `fwup`/`libmnl` (Nerves docs) — **não** necessário para as tasks deste plano (só `MIX_TARGET=host`).

---

### Task 1: Scaffold do app de contratos `core/`

Cria o app `:core` como lib Elixir pura com o ferramental de qualidade da casa. Deliverable: `core/` compila e `mix test` passa (teste default gerado).

**Files:**
- Create: `core/mix.exs`, `core/lib/core.ex`, `core/test/test_helper.exs`, `core/test/core_test.exs` (via `mix new`)
- Create: `core/.tool-versions`, `core/.formatter.exs`, `core/.credo.exs`, `core/.check.exs`

**Interfaces:**
- Consumes: nada (primeiro task).
- Produces: app `:core` compilável; base para os módulos `Core.*`.

- [ ] **Step 1: Gerar a lib**

Run (a partir da raiz `plantex/`):
```bash
mix new core --module Core
```
Expected: cria `core/` com `lib/core.ex`, `test/`, `mix.exs`.

- [ ] **Step 2: Fixar toolchain**

Create `core/.tool-versions`:
```
erlang 27.3.4.11
elixir 1.19.5-otp-27
```

- [ ] **Step 3: Definir deps e projeto**

Replace `core/mix.exs` with:
```elixir
defmodule Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :core,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts",
        plt_add_apps: [:ex_unit, :mix]
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false}
    ]
  end
end
```

- [ ] **Step 4: Formatter e credo**

Create `core/.formatter.exs`:
```elixir
[
  inputs: ["{mix,.formatter,.credo,.check}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

Create `core/.credo.exs`:
```elixir
%{
  configs: [
    %{
      name: "default",
      files: %{included: ["lib/", "test/"], excluded: []},
      strict: true,
      checks: %{enabled: [], disabled: []}
    }
  ]
}
```

Create `core/.check.exs`:
```elixir
[
  tools: [
    {:credo, "mix credo --strict"}
  ]
]
```

- [ ] **Step 5: Instalar deps e testar**

Run:
```bash
cd core && mix deps.get && mix test
```
Expected: deps baixam; teste default `core_test.exs` PASSA (1 test, 0 failures).

- [ ] **Step 6: Commit**

```bash
cd .. && git add core && git commit -m "feat(core): scaffold do app de contratos com gate de qualidade"
```

---

### Task 2: Struct `Core.Telemetry.Reading`

Contrato de uma leitura de sensor no fio. TDD.

**Files:**
- Create: `core/lib/core/telemetry/reading.ex`
- Test: `core/test/core/telemetry/reading_test.exs`

**Interfaces:**
- Consumes: app `:core` (Task 1).
- Produces: `%Core.Telemetry.Reading{sensor_id: String.t(), kind: atom(), value: number(), unit: String.t() | nil, measured_at: integer()}` com `@enforce_keys [:sensor_id, :kind, :value, :measured_at]`. `kind` ∈ `:air_temp | :air_humidity | :soil_moisture` (extensível). `measured_at` = unix ms.

- [ ] **Step 1: Escrever o teste que falha**

Create `core/test/core/telemetry/reading_test.exs`:
```elixir
defmodule Core.Telemetry.ReadingTest do
  use ExUnit.Case, async: true
  alias Core.Telemetry.Reading

  test "constrói uma leitura válida" do
    r = %Reading{sensor_id: "s1", kind: :air_temp, value: 23.5, unit: "C", measured_at: 1_720_000_000_000}
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
```

- [ ] **Step 2: Rodar o teste e ver falhar**

Run: `cd core && mix test test/core/telemetry/reading_test.exs`
Expected: FAIL — `Core.Telemetry.Reading.__struct__/1 is undefined`.

- [ ] **Step 3: Implementar o struct**

Create `core/lib/core/telemetry/reading.ex`:
```elixir
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
```

- [ ] **Step 4: Rodar o teste e ver passar**

Run: `cd core && mix test test/core/telemetry/reading_test.exs`
Expected: PASS (2 tests, 0 failures).

- [ ] **Step 5: Commit**

```bash
cd .. && git add core && git commit -m "feat(core): struct Core.Telemetry.Reading"
```

---

### Task 3: Struct `Core.Control.Command`

Contrato de um comando de atuador. TDD.

**Files:**
- Create: `core/lib/core/control/command.ex`
- Test: `core/test/core/control/command_test.exs`

**Interfaces:**
- Consumes: app `:core`.
- Produces: `%Core.Control.Command{id: String.t(), actuator_id: String.t(), action: atom(), params: map(), issued_at: integer()}` com `@enforce_keys [:id, :actuator_id, :action]`. `action` ∈ `:on | :off | :pulse`. `params` default `%{}` (ex.: `%{"ms" => 5000}` para `:pulse`).

- [ ] **Step 1: Escrever o teste que falha**

Create `core/test/core/control/command_test.exs`:
```elixir
defmodule Core.Control.CommandTest do
  use ExUnit.Case, async: true
  alias Core.Control.Command

  test "constrói um comando de pulso" do
    c = %Command{id: "c1", actuator_id: "a1", action: :pulse, params: %{"ms" => 5000}, issued_at: 1_720_000_000_000}
    assert c.action == :pulse
    assert c.params == %{"ms" => 5000}
  end

  test "params default é mapa vazio" do
    c = %Command{id: "c1", actuator_id: "a1", action: :off}
    assert c.params == %{}
  end
end
```

- [ ] **Step 2: Rodar o teste e ver falhar**

Run: `cd core && mix test test/core/control/command_test.exs`
Expected: FAIL — `Core.Control.Command.__struct__/1 is undefined`.

- [ ] **Step 3: Implementar o struct**

Create `core/lib/core/control/command.ex`:
```elixir
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
```

- [ ] **Step 4: Rodar o teste e ver passar**

Run: `cd core && mix test test/core/control/command_test.exs`
Expected: PASS (2 tests, 0 failures).

- [ ] **Step 5: Commit**

```bash
cd .. && git add core && git commit -m "feat(core): struct Core.Control.Command"
```

---

### Task 4: Struct `Core.Photo`

Contrato dos metadados de uma foto (os bytes vão por outro caminho). TDD.

**Files:**
- Create: `core/lib/core/photo.ex`
- Test: `core/test/core/photo_test.exs`

**Interfaces:**
- Consumes: app `:core`.
- Produces: `%Core.Photo{station_id: String.t(), captured_at: integer(), content_type: String.t(), width: integer() | nil, height: integer() | nil, byte_size: integer() | nil}` com `@enforce_keys [:station_id, :captured_at, :content_type]`.

- [ ] **Step 1: Escrever o teste que falha**

Create `core/test/core/photo_test.exs`:
```elixir
defmodule Core.PhotoTest do
  use ExUnit.Case, async: true
  alias Core.Photo

  test "constrói metadados de foto" do
    p = %Photo{station_id: "st1", captured_at: 1_720_000_000_000, content_type: "image/jpeg", width: 1920, height: 1080, byte_size: 204_800}
    assert p.content_type == "image/jpeg"
    assert p.width == 1920
  end
end
```

- [ ] **Step 2: Rodar o teste e ver falhar**

Run: `cd core && mix test test/core/photo_test.exs`
Expected: FAIL — `Core.Photo.__struct__/1 is undefined`.

- [ ] **Step 3: Implementar o struct**

Create `core/lib/core/photo.ex`:
```elixir
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
```

- [ ] **Step 4: Rodar o teste e ver passar**

Run: `cd core && mix test test/core/photo_test.exs`
Expected: PASS (1 test, 0 failures).

- [ ] **Step 5: Commit**

```bash
cd .. && git add core && git commit -m "feat(core): struct Core.Photo"
```

---

### Task 5: `Core.Protocol` (encode/decode + property tests)

O tradutor struct ↔ mapa de fio, com versão. Property test garante round-trip exato — é o contrato que server e firmware nunca podem divergir.

**Files:**
- Create: `core/lib/core/protocol.ex`
- Test: `core/test/core/protocol_test.exs`
- Create: `core/test/support/generators.ex`

**Interfaces:**
- Consumes: `Core.Telemetry.Reading` (Task 2), `Core.Control.Command` (Task 3), `Core.Photo` (Task 4).
- Produces:
  - `Core.Protocol.version/0 :: pos_integer()`
  - `Core.Protocol.encode(Reading.t() | Command.t() | Photo.t()) :: map()` (mapa de chaves string, JSON-áveis)
  - `Core.Protocol.decode(map()) :: {:ok, Reading.t() | Command.t() | Photo.t()} | {:error, :unknown_message}`

- [ ] **Step 1: Gerador de dados para property tests**

Create `core/test/support/generators.ex`:
```elixir
defmodule Core.Generators do
  @moduledoc "Geradores StreamData para os contratos do Core."
  import StreamData
  alias Core.Control.Command
  alias Core.Photo
  alias Core.Telemetry.Reading

  def reading do
    gen all sensor_id <- string(:alphanumeric, min_length: 1),
            kind <- member_of([:air_temp, :air_humidity, :soil_moisture]),
            value <- one_of([integer(), float()]),
            unit <- one_of([constant(nil), string(:alphanumeric, min_length: 1)]),
            measured_at <- integer(0..4_000_000_000_000) do
      %Reading{sensor_id: sensor_id, kind: kind, value: value, unit: unit, measured_at: measured_at}
    end
  end

  def command do
    gen all id <- string(:alphanumeric, min_length: 1),
            actuator_id <- string(:alphanumeric, min_length: 1),
            action <- member_of([:on, :off, :pulse]),
            params <- map_of(string(:alphanumeric, min_length: 1), integer()),
            issued_at <- integer(0..4_000_000_000_000) do
      %Command{id: id, actuator_id: actuator_id, action: action, params: params, issued_at: issued_at}
    end
  end

  def photo do
    gen all station_id <- string(:alphanumeric, min_length: 1),
            captured_at <- integer(0..4_000_000_000_000),
            content_type <- member_of(["image/jpeg", "image/png"]),
            width <- integer(1..10_000),
            height <- integer(1..10_000),
            byte_size <- integer(0..50_000_000) do
      %Photo{station_id: station_id, captured_at: captured_at, content_type: content_type, width: width, height: height, byte_size: byte_size}
    end
  end
end
```

- [ ] **Step 2: Escrever os testes que falham**

Create `core/test/core/protocol_test.exs`:
```elixir
defmodule Core.ProtocolTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Core.Control.Command
  alias Core.Protocol
  alias Core.Telemetry.Reading

  test "encode marca versão e tipo" do
    r = %Reading{sensor_id: "s1", kind: :air_temp, value: 1, measured_at: 0}
    encoded = Protocol.encode(r)
    assert encoded["v"] == Protocol.version()
    assert encoded["type"] == "reading"
  end

  test "decode de mensagem desconhecida" do
    assert Protocol.decode(%{"v" => 999, "type" => "nope"}) == {:error, :unknown_message}
  end

  property "round-trip de Reading" do
    check all r <- Core.Generators.reading() do
      assert Protocol.decode(Protocol.encode(r)) == {:ok, r}
    end
  end

  property "round-trip de Command" do
    check all c <- Core.Generators.command() do
      assert Protocol.decode(Protocol.encode(c)) == {:ok, c}
    end
  end

  property "round-trip de Photo" do
    check all p <- Core.Generators.photo() do
      assert Protocol.decode(Protocol.encode(p)) == {:ok, p}
    end
  end

  test "actions e kinds sobrevivem ao fio como átomos" do
    c = %Command{id: "c", actuator_id: "a", action: :pulse, params: %{}}
    assert {:ok, %Command{action: :pulse}} = Protocol.decode(Protocol.encode(c))
  end
end
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd core && mix test test/core/protocol_test.exs`
Expected: FAIL — `Core.Protocol.encode/1 is undefined`.

- [ ] **Step 4: Implementar o protocolo**

Create `core/lib/core/protocol.ex`:
```elixir
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
```

- [ ] **Step 5: Carregar o support no test_helper**

Verify `core/mix.exs` já compila `test/support` em `:test` (feito na Task 1, `elixirc_paths(:test)`). Nenhuma mudança de código; só confirmar.

Run: `cd core && MIX_ENV=test mix compile`
Expected: compila sem erro (inclui `test/support/generators.ex`).

- [ ] **Step 6: Rodar e ver passar**

Run: `cd core && mix test test/core/protocol_test.exs`
Expected: PASS (todos os tests + 3 properties, 0 failures).

> Nota: `String.to_existing_atom/1` é seguro aqui porque os átomos `:air_temp`, `:pulse`, etc. já existem (definidos nos structs carregados). Isso evita atom-leak de mensagens maliciosas.

- [ ] **Step 7: Commit**

```bash
cd .. && git add core && git commit -m "feat(core): Core.Protocol com round-trip property-tested"
```

---

### Task 6: Gate de qualidade do `core` verde

Roda o `mix check` completo do `core` e resolve qualquer warning de compile/credo/dialyzer. Deliverable: `cd core && mix check` sai 0.

**Files:**
- Modify: qualquer arquivo `core/lib/**` que gere warning (conforme necessário)
- Create: `core/priv/plts/.gitkeep` (diretório do PLT do dialyzer)

**Interfaces:**
- Consumes: todo o `core/` (Tasks 1–5).
- Produces: baseline de qualidade verde do `core`.

- [ ] **Step 1: Garantir diretório do PLT**

```bash
mkdir -p core/priv/plts && touch core/priv/plts/.gitkeep
```

- [ ] **Step 2: Rodar o check completo**

Run: `cd core && mix check`
Expected: primeira execução constrói o PLT do dialyzer (demora); ao fim, todas as ferramentas PASSAM (compiler `-Werror`, formatter, credo `--strict`, dialyzer, ex_unit, unused_deps).

- [ ] **Step 3: Corrigir o que aparecer**

Se `mix format --check-formatted` acusar, rode `mix format`. Se o credo/dialyzer apontar, corrija na raiz (proibido silenciar warning — ver `~/elixir-references` / `Tavano_rfc`). Re-rode `mix check` até sair limpo.

- [ ] **Step 4: Ignorar PLTs no git**

Add to `.gitignore` (raiz) se ainda não coberto:
```
/core/priv/plts/*.plt
/core/priv/plts/*.plt.hash
```

- [ ] **Step 5: Commit**

```bash
git add core .gitignore && git commit -m "chore(core): gate de qualidade (mix check) verde"
```

---

### Task 7: Scaffold do `server/` (Phoenix) ligado ao `core`

App Phoenix `:plantex` com Postgres, dependendo do `core` por `path:`, com `mix check` + sobelow. Deliverable: `server` compila, `mix test` passa e o app referencia `Core.Protocol`.

**Files:**
- Create: `server/**` (via `mix phx.new`)
- Modify: `server/mix.exs` (dep `core` por path; ferramental)
- Create: `server/.tool-versions`, `server/.check.exs`
- Create: `server/test/plantex/protocol_bridge_test.exs`
- Create: `server/lib/plantex/protocol_bridge.ex`

**Interfaces:**
- Consumes: `Core.Protocol.decode/1` (Task 5).
- Produces: app `:plantex` compilável com `core` linkado; `Plantex.ProtocolBridge.ingest/1` provando o link.

- [ ] **Step 1: Gerar o Phoenix na pasta `server/`**

Run (da raiz `plantex/`):
```bash
mix phx.new server --app plantex --module Plantex
```
Expected: gera app Phoenix em `server/` com app `:plantex`, módulos `Plantex`/`PlantexWeb`, Ecto+Postgres. Responda `Y` para buscar deps.

- [ ] **Step 2: Fixar toolchain**

Create `server/.tool-versions`:
```
erlang 27.3.4.11
elixir 1.19.5-otp-27
```

- [ ] **Step 3: Ligar o `core` e o ferramental**

In `server/mix.exs`, dentro de `defp deps do [...]`, adicione:
```elixir
      {:core, path: "../core"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
```
And in `project/0` add:
```elixir
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_local_path: "priv/plts", plt_core_path: "priv/plts", plt_add_apps: [:ex_unit, :mix]],
```

Create `server/.check.exs`:
```elixir
[
  tools: [
    {:credo, "mix credo --strict"},
    {:sobelow, "mix sobelow --config"}
  ]
]
```

- [ ] **Step 4: Escrever o teste que prova o link com o core (falha)**

Create `server/test/plantex/protocol_bridge_test.exs`:
```elixir
defmodule Plantex.ProtocolBridgeTest do
  use ExUnit.Case, async: true

  test "decodifica uma mensagem de reading usando o Core" do
    wire = Core.Protocol.encode(%Core.Telemetry.Reading{
      sensor_id: "s1", kind: :air_temp, value: 22.0, measured_at: 0
    })

    assert {:ok, %Core.Telemetry.Reading{kind: :air_temp}} = Plantex.ProtocolBridge.ingest(wire)
  end

  test "mensagem inválida vira erro" do
    assert {:error, :unknown_message} = Plantex.ProtocolBridge.ingest(%{"nope" => true})
  end
end
```

- [ ] **Step 5: Rodar e ver falhar**

Run: `cd server && mix deps.get && mix test test/plantex/protocol_bridge_test.exs`
Expected: FAIL — `Plantex.ProtocolBridge.ingest/1 is undefined`.

- [ ] **Step 6: Implementar a ponte mínima**

Create `server/lib/plantex/protocol_bridge.ex`:
```elixir
defmodule Plantex.ProtocolBridge do
  @moduledoc """
  Fronteira fina entre o transporte (Channel) e os contratos do `Core`.
  Nas fases seguintes, delega o resultado decodificado aos contexts
  (`Telemetry.ingest/1`, `Vision.store_photo/1`, ...).
  """
  @spec ingest(map()) :: {:ok, struct()} | {:error, :unknown_message}
  defdelegate ingest(message), to: Core.Protocol, as: :decode
end
```

- [ ] **Step 7: Rodar e ver passar**

Run: `cd server && mix test test/plantex/protocol_bridge_test.exs`
Expected: PASS (2 tests, 0 failures).

- [ ] **Step 8: Suite + check verdes**

Run:
```bash
cd server && mix test && mkdir -p priv/plts && mix check
```
Expected: suíte gerada pelo Phoenix + os 2 tests passam; `mix check` verde (rode `mix format` se necessário). Postgres precisa estar de pé para a suíte Ecto padrão (`mix ecto.create` roda no `test`).

- [ ] **Step 9: Commit**

```bash
cd .. && git add server .gitignore && git commit -m "feat(server): scaffold Phoenix :plantex ligado ao core"
```

---

### Task 8: Scaffold do `firmware/` (Nerves) + behaviour `Hardware`

App Nerves `:firmware` targets `host`+`rpi3`, dependendo do `core` por path, com o behaviour `Hardware` e o adapter `Sim`. Deliverable: `MIX_TARGET=host mix test` passa lendo sensores simulados.

**Files:**
- Create: `firmware/**` (via `mix nerves.new`)
- Modify: `firmware/mix.exs` (dep `core` por path; circuits)
- Create: `firmware/.tool-versions`, `firmware/.check.exs`
- Create: `firmware/lib/firmware/hardware.ex` (behaviour)
- Create: `firmware/lib/firmware/hardware/sim.ex` (adapter)
- Test: `firmware/test/firmware/hardware/sim_test.exs`

**Interfaces:**
- Consumes: `Core.Telemetry.Reading` (Task 2).
- Produces:
  - Behaviour `Firmware.Hardware` com callback `read_sensor(sensor_id :: String.t(), kind :: atom()) :: {:ok, number()} | {:error, term()}`.
  - `Firmware.Hardware.Sim.read_sensor/2` retornando valor determinístico por `kind`.

- [ ] **Step 1: Instalar o bootstrap do Nerves (se ainda não)**

Run: `mix archive.install hex nerves_bootstrap`
Expected: instala a task `mix nerves.new`.

- [ ] **Step 2: Gerar o firmware**

Run (da raiz `plantex/`):
```bash
mix nerves.new firmware --app firmware --module Firmware
```
Expected: gera `firmware/` com `config/target.exs`, `mix.exs` com `@target`, `lib/firmware/application.ex`. Responda `Y` para buscar deps.

- [ ] **Step 3: Fixar toolchain**

Create `firmware/.tool-versions`:
```
erlang 27.3.4.11
elixir 1.19.5-otp-27
```

- [ ] **Step 4: Ligar `core`, circuits e ferramental**

In `firmware/mix.exs`, no bloco `deps/0`, adicione (junto às deps existentes geradas):
```elixir
      {:core, path: "../core"},
      {:circuits_gpio, "~> 2.0", targets: @all_targets},
      {:circuits_i2c, "~> 2.0", targets: @all_targets},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
```
(`@all_targets` já é definido pelo gerador do Nerves no topo do `mix.exs`.)

Create `firmware/.check.exs`:
```elixir
[
  tools: [
    {:credo, "mix credo --strict"},
    # dialyzer fora do gate do firmware: PLT cross-target é custoso; roda no host manualmente
    {:dialyzer, false}
  ]
]
```

- [ ] **Step 5: Escrever o teste do adapter Sim (falha)**

Create `firmware/test/firmware/hardware/sim_test.exs`:
```elixir
defmodule Firmware.Hardware.SimTest do
  use ExUnit.Case, async: true
  alias Firmware.Hardware.Sim

  test "implementa o behaviour Hardware" do
    behaviours = Firmware.Hardware.Sim.module_info(:attributes)[:behaviour] || []
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
```

- [ ] **Step 6: Rodar e ver falhar**

Run: `cd firmware && MIX_TARGET=host mix deps.get && MIX_TARGET=host mix test`
Expected: FAIL — `Firmware.Hardware.Sim` / `Firmware.Hardware` undefined.

- [ ] **Step 7: Implementar o behaviour**

Create `firmware/lib/firmware/hardware.ex`:
```elixir
defmodule Firmware.Hardware do
  @moduledoc """
  Port de hardware (hexagonal). Adapters: `Firmware.Hardware.Circuits` (real, no Pi)
  e `Firmware.Hardware.Sim` (fake, no host). A escolha do adapter é injetada, nunca
  hard-coded — assim a malha fechada roda e é testada no Mac.
  """
  @callback read_sensor(sensor_id :: String.t(), kind :: atom()) ::
              {:ok, number()} | {:error, term()}
end
```

- [ ] **Step 8: Implementar o adapter Sim**

Create `firmware/lib/firmware/hardware/sim.ex`:
```elixir
defmodule Firmware.Hardware.Sim do
  @moduledoc "Adapter de hardware simulado para desenvolvimento no host (sem Pi)."
  @behaviour Firmware.Hardware

  @impl Firmware.Hardware
  def read_sensor(_sensor_id, :air_temp), do: {:ok, 23.5}
  def read_sensor(_sensor_id, :air_humidity), do: {:ok, 55.0}
  def read_sensor(_sensor_id, :soil_moisture), do: {:ok, 42.0}
  def read_sensor(_sensor_id, _kind), do: {:error, :unsupported_kind}
end
```

- [ ] **Step 9: Rodar e ver passar**

Run: `cd firmware && MIX_TARGET=host mix test`
Expected: PASS (3 tests, 0 failures).

- [ ] **Step 10: Check do firmware no host**

Run: `cd firmware && MIX_TARGET=host mix check`
Expected: verde (compiler `-Werror`, formatter, credo `--strict`, ex_unit). Rode `mix format` se necessário.

- [ ] **Step 11: Commit**

```bash
cd .. && git add firmware .gitignore && git commit -m "feat(firmware): scaffold Nerves :firmware + behaviour Hardware e adapter Sim"
```

---

### Task 9: CI (GitHub Actions) sobre o poncho

Um workflow que roda os checks dos três apps a cada push/PR. Deliverable: `.github/workflows/ci.yml` versionado, com jobs verdes localmente reproduzíveis.

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `core/`, `server/`, `firmware/` (Tasks 1–8).
- Produces: pipeline de CI do repo.

- [ ] **Step 1: Escrever o workflow**

Create `.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

env:
  MIX_ENV: test
  ELIXIR_VERSION: "1.19.5-otp-27"
  OTP_VERSION: "27.3.4.11"

jobs:
  core:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}
      - run: mix deps.get
        working-directory: core
      - run: mix check
        working-directory: core

  server:
    runs-on: ubuntu-latest
    services:
      db:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}
      - run: mix deps.get
        working-directory: server
      - run: mix check
        working-directory: server

  firmware:
    runs-on: ubuntu-latest
    env:
      MIX_TARGET: host
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}
      - run: mix deps.get
        working-directory: firmware
      - run: mix check
        working-directory: firmware
```

> Nota: `server` usa o Postgres do bloco `services`. Confirme que `server/config/test.exs` aponta o `hostname: "localhost"` e credenciais `postgres/postgres` (ajuste o default gerado pelo Phoenix se preciso, em passo de correção).

- [ ] **Step 2: Validar o YAML localmente**

Run: `cd core && mix check && cd ../firmware && MIX_TARGET=host mix check`
Expected: os mesmos comandos do CI passam local (o job `server` exige Postgres local para reproduzir).

- [ ] **Step 3: Commit**

```bash
git add .github && git commit -m "ci: pipeline do poncho (core/server/firmware)"
```

---

## Self-Review

**1. Spec coverage (Fase 0):** poncho `core`/`server`/`firmware` (Tasks 1,7,8) ✅ · `Core.Protocol` + property tests (Task 5) ✅ · contratos `Reading`/`Command`/`Photo` (Tasks 2–4) ✅ · gate `mix check` (Tasks 6,7,8) ✅ · CI (Task 9) ✅ · behaviour `Hardware` + `Sim` (Task 8) ✅ · `.tool-versions` fixado ✅. Fases 1–6 são planos futuros, fora deste escopo por design.

**2. Placeholder scan:** todo step de código traz o código completo; comandos com output esperado; sem "TBD"/"handle edge cases". ✅

**3. Type consistency:** `Core.Protocol.encode/1`/`decode/1`, `Reading`/`Command`/`Photo` com os mesmos campos e `@enforce_keys` entre Tasks 2–5; `Plantex.ProtocolBridge.ingest/1` delega a `decode/1` (Task 7); `Firmware.Hardware.read_sensor/2` idêntico entre behaviour, adapter e teste (Task 8). ✅

## Riscos de execução

- **Postgres no CI:** o default gerado pelo Phoenix pode divergir do serviço; a nota da Task 9 Step 1 cobre o ajuste de `config/test.exs`.
- **Versão Elixir/OTP × Nerves:** `1.19.5-otp-27` no host é ok; o build `rpi3` (fora deste plano) usa a OTP cross-compilada do `nerves_system_rpi3` — validar alinhamento no primeiro `mix firmware` (Fase 1).
- **`String.to_existing_atom` no decode:** seguro porque os structs (com seus átomos) são carregados junto ao `Core.Protocol`; property tests cobrem os kinds/actions válidos.
