# Plantex — Design / Refinamento

> **Data:** 2026-07-06 · **Status:** aprovado (brainstorming) · **Próximo passo:** plano de implementação (writing-plans)

Plantex é um app de **horticultura de precisão** para acompanhar, controlar e
**comparar o crescimento de plantas**. Ele registra plantas, mede o ambiente por
sensores, tira fotos diárias (time-lapse), pode acionar atuadores (bomba d'água,
luz, ventilação) e cruza tudo isso em gráficos para responder à pergunta central:

> _Qual combinação de condições faz esta planta crescer melhor?_

## Princípios do projeto

1. **Cultivo genérico.** Plantex serve para **qualquer planta**. A planta canônica
   de exemplos, seeds, fixtures e documentação é o **tomate-cereja**.
2. **Zero apologia a drogas.** Nenhum texto, exemplo, nome de módulo, seed ou
   comentário faz referência a substâncias ilícitas. Isto é um projeto público de
   horticultura/IoT. É um princípio de projeto, não uma nota de rodapé.
3. **Padrão da casa (Elixir):** clean code, DDD, hexagonal (ports & adapters),
   módulos profundos, TDD, DI passando structs (não IDs), zero tolerância a
   warning de Dialyzer/Credo. Referências: `~/elixir-references`.
4. **Segurança física primeiro.** Água + eletrônica + planta viva. Todo atuador
   tem fail-safe local e o sistema roda com a mesma qualidade em modo só-observação.

---

## Escopo

### MVP (fase 1)
- Cadastro de **postos** (stations), **plantas** e **espécies** (perfil com faixas ideais).
- **Sensores MVP:** temperatura + umidade do **ar** e umidade do **solo**.
- **Foto diária** por posto → time-lapse + métrica de **vigor** (altura, área verde,
  nº de folhas) reaproveitando o pipeline do `camerex`.
- **Gráficos ao vivo** por posto (série temporal dos sensores + vigor).
- **Atuadores** com **modo selecionável por atuador/zona**: `observe` · `manual` · `auto`.
  - `observe`: só lê, não aciona.
  - `manual`: botão no LiveView aciona o relé.
  - `auto`: motor de regras aciona sozinho (malha fechada).
- **Marcos manuais** (germinação, 1ª flor, colheita, saúde 0–10, rendimento) como
  âncora de qualidade.
- **Firmware Nerves** no Raspberry Pi 3B (target `rpi3`) lendo sensores/acionando
  relés via `Circuits`, mais adapter simulado para desenvolver no Mac.

### Futuro (fora do MVP, já modelado no schema)
- Sensores adicionais: **pH do solo**, **NPK/nutrientes** (sonda RS485), **luz**
  (BH1750), **temperatura do solo** (DS18B20) — entram como `Sensor` de novo `kind`,
  sem migração de arquitetura. Enquanto não há sonda, pH/NPK entram como **leitura manual**.
- **Experimentos comparativos** entre vários postos/Pis (a "planta perfeita").
- Múltiplos Pis / múltiplos postos por Pi.
- Alertas/notificações, exportação de dados, relatórios.

### Não-objetivos (YAGNI por ora)
- App mobile nativo (LiveView responsivo cobre).
- Nuvem / multi-tenant / login social — roda local na rede do Lucas.
- Controle climático industrial (PID fino, CO₂, etc.).

---

## Arquitetura

### Monorepo poncho — 1 repo Git, 3 apps isolados

Padrão **poncho project** (apps irmãos ligados por `path:`), recomendado pelo
ecossistema Nerves em vez de umbrella — umbrella compartilha build/config de forma
que conflita com os targets de firmware.

```
plantex/                     # um repo · git pull único · versão única
├─ core/                     # Elixir puro — contratos compartilhados
│                            #   SEM deps de Phoenix nem Nerves
├─ server/                   # Phoenix + Postgres + LiveView (Mac/servidor)
├─ firmware/                 # Nerves (target rpi3) — Raspberry Pi 3B
└─ docs/                     # este spec + requisitos de hardware
```

**Isolamento "um jeito no Pi, outro no servidor":**

| Alvo | Como builda/roda | Carrega |
|---|---|---|
| **Raspberry Pi 3B** | `MIX_TARGET=rpi3 mix firmware` → `mix burn`/`mix upload` | só `firmware/` + `core/` |
| **Servidor (Mac)** | release Phoenix + Postgres | só `server/` + `core/` |
| **Dev no Mac (sem hardware)** | `MIX_TARGET=host` no `firmware/` | `firmware/` com adapter `Sim` |

Os três só se conhecem pelos **contratos do `core/`**. Deps, build e config
totalmente separados por app.

### Hexagonal no hardware (ports & adapters)

Behaviour `Hardware` no `firmware/`, com dois adapters:

- `Hardware.Circuits` — real, no Pi (`circuits_gpio`, `circuits_i2c`).
- `Hardware.Sim` — fake determinístico, no Mac (`MIX_TARGET=host`).

Resultado: **a malha fechada inteira roda e é testada no Mac** sem tocar em
hardware; o deploy pro Pi só troca o adapter.

### Transporte

**Phoenix Channels.** O `firmware/` é cliente (via **Slipstream**): empurra
telemetria e fotos pra cima e escuta comandos de atuador pra baixo. Reconecta
sozinho quando o Pi cai/volta. Um único `DeviceSocket` autentica o device por
token; um `DeviceChannel` por device.

---

## Modelo de domínio

Contexts no `server/` (convenção `nome.ex` como fronteira pública + pasta `nome/`
com schemas e módulos internos).

### `Cultivation` — o que se cultiva
| Schema | Campos-chave |
|---|---|
| `Station` | `name`, `location`, `species_id`, `device_id?` (binding físico) |
| `Plant` | `station_id`, `species_id`, `planted_on`, `stage`, `status` — permite trocar de planta no mesmo posto entre ciclos |
| `Species` | `name`, faixas ideais (`temp_min/max`, `soil_moisture_min/max`, `ph_min/max`, `light_hours`), notas — seed inicial: **tomate-cereja** |
| `Milestone` | `plant_id`, `kind` (`germination` \| `first_flower` \| `harvest` \| `health_score` \| `yield`), `value`, `note`, `occurred_at` |

### `Devices` — o mapa do hardware (o "registro da Pi")
| Schema | Campos-chave |
|---|---|
| `Device` | `identifier`, `firmware_version`, `last_seen_at`, `status` (presença) |
| `Sensor` | `device_id`, `station_id`, `kind` (`air_temp` \| `air_humidity` \| `soil_moisture` \| futuros), `unit`, `address`/`pin`, `calibration` |
| `Actuator` | `device_id`, `station_id`, `kind` (`pump` \| `light` \| `fan` \| ...), **`mode`** (`observe`\|`manual`\|`auto`), `max_runtime_ms`, `cooldown_ms`, `pin` |

### `Telemetry` — série temporal
| Schema | Campos-chave |
|---|---|
| `Reading` | `sensor_id`, `station_id`, `kind`, `value`, `measured_at` — alto volume; índice `(station_id, kind, measured_at)`; rollups/particionamento como evolução futura |

### `Control` — atuação, malha fechada e segurança
| Schema | Campos-chave |
|---|---|
| `Command` | `actuator_id`, `source` (`manual`\|`rule`), `payload`, `issued_at`, `executed_at`, `outcome` |
| `Rule` | `station_id`/`actuator_id`, `condition` (ex.: `soil_moisture < 30`), `action` (ex.: `pump 10s`), `enabled` |

### `Vision` — foto, time-lapse e vigor
| Schema | Campos-chave |
|---|---|
| `Photo` | `station_id`, `path`, `captured_at`, `width`, `height`, `meta` |
| `GrowthMetric` | `station_id`, `photo_id`, `height`, `green_area`, `leaf_count`, `vigor_score`, `computed_at` |

### `Analysis` — cruzar ambiente × resultado
| Schema | Campos-chave |
|---|---|
| `Experiment` | `name`, `description` |
| `ExperimentStation` | join `experiment_id`↔`station_id` |

`Analysis` é read-heavy: lê `Reading` + `GrowthMetric` + `Milestone` dos postos de
um `Experiment` e produz correlações/gráficos comparativos ("qual receita fez o
tomate-cereja crescer melhor").

---

## Contratos do `core/`

Elixir puro, sem Phoenix/Nerves. Único vocabulário compartilhado no fio:

- `Core.Telemetry.Reading` — struct de leitura de sensor.
- `Core.Control.Command` — struct de comando de atuador.
- `Core.Photo` — metadados de foto.
- `Core.Protocol` — versão do protocolo + `encode/1`/`decode/1` das mensagens do
  Channel. Coberto por **property tests** (stream_data): `decode(encode(x)) == {:ok, x}`.

---

## Fluxo de dados

1. **Sensores.** Firmware lê a cada `N`s (via `Hardware`) → `Core.Telemetry.Reading`
   → Channel → `Telemetry.ingest/1` → Postgres → `Phoenix.PubSub` → **gráfico ao
   vivo** no LiveView.
2. **Foto.** Firmware captura (diária/agendada) → sobe pelo Channel → `Vision.store_photo/1`
   → **job Oban** roda o vigor (pipeline camerex) → `GrowthMetric`.
3. **Controle.**
   - *Manual:* botão no LiveView → `Control.issue_command/2` (valida `mode` +
     `cooldown` + limites) → Channel → `Actuators` executa → `outcome` volta → `Command` atualizado.
   - *Auto:* motor de regras avalia `Rule` **só** de postos em `mode: auto`, disparado
     por nova leitura → mesmo caminho de comando. Fail-safe do firmware sempre ativo.
4. **Análise.** `Analysis` lê a base histórica de um `Experiment` → gráficos comparativos.

---

## Modos de operação (por atuador/zona)

| Modo | Lê sensores | Aciona atuador | Quem decide |
|---|---|---|---|
| `observe` | ✅ | ❌ | ninguém (passivo) |
| `manual` | ✅ | ✅ | humano (botão) |
| `auto` | ✅ | ✅ | motor de regras |

O mesmo sistema é uma estufa autônoma **ou** um monitor passivo, dependendo da
config — com override manual sempre disponível.

## Segurança dos atuadores

- **Fail-safe local (firmware):** todo acionamento tem `max_runtime` que o próprio
  Pi corta, **mesmo se a rede cair** — a bomba nunca fica ligada por rede perdida.
- **Cooldown + gating de modo (server):** comando fora do `mode` correto é rejeitado.
- **Kill / override manual** sempre acessível na UI.
- **Dado velho não dispara:** regra `auto` não roda com leitura `stale` (device offline).
- **Elétrica:** atuadores nunca são alimentados pela GPIO do Pi — relé + fonte
  externa + terra comum (detalhado na doc de hardware).

---

## Firmware (Nerves) — detalhes

Target `nerves_system_rpi3`. Árvore de supervisão em `firmware/`:

- `Sensors` — GenServer de polling; lê cada `Sensor` pelo `Hardware` e emite telemetria.
- `Actuators` — recebe `Command`, executa via `Hardware`, aplica fail-safe local.
- `Camera` — captura snapshot (ver risco abaixo).
- `Link` — cliente Slipstream; buffer local quando offline, reenvia ao reconectar.
- `Hardware` (behaviour) + `Circuits`/`Sim`.

**Deploy:** SD com firmware (`mix burn`) na primeira vez; depois OTA por rede
(`mix upload` / `nerves_ssh`). Dev diário: `MIX_TARGET=host` com `Hardware.Sim`.

---

## Testes e qualidade

- **TDD** em todos os contexts.
- `Hardware` e transporte **mockados** (Mox/Mimic) → **malha fechada testável 100%
  no Mac** com adapter `Sim`.
- **Property tests** (stream_data) no `Core.Protocol`.
- **Factories** (ExMachina) para os schemas.
- Gate `mix check`: compile `-Werror`, `format`, `credo --strict`, `dialyzer`,
  `sobelow` (no `server/`), cobertura (excoveralls).

---

## Faseamento (roadmap)

| Fase | Entrega |
|---|---|
| **0 — Fundação** | Poncho `core`/`server`/`firmware`; `core` + `Core.Protocol` com property tests; CI + `mix check`. |
| **1 — Spike câmera Nerves** | Validar captura de foto no rpi3 (o risco nº 1). Decide CSI vs USB antes de investir no resto. |
| **2 — Telemetria** | `Devices` + `Telemetry`; `DeviceChannel`; firmware lendo sensores (`Sim` → real); gráfico ao vivo. |
| **3 — Cultivo + vigor** | `Cultivation`; `Vision` com foto → vigor (camerex) via Oban; time-lapse. |
| **4 — Controle** | `Control` com `observe`/`manual`; fail-safe; botões na UI. |
| **5 — Malha fechada** | `Rule` + motor de regras (`auto`); interlocks completos. |
| **6 — Comparação** | `Analysis` + `Experiment`; gráficos comparativos. |

---

## Riscos

| # | Risco | Mitigação |
|---|---|---|
| 1 | **Captura de câmera sob Nerves no rpi3** é a parte mais imatura | Spike dedicado na fase 1; plano B webcam USB / captura fora do firmware |
| 2 | Pi 3B (1GB RAM) apertado se pedirem visão computacional no device | Visão roda no **server** (Oban); firmware só captura e sobe |
| 3 | Sensor de umidade de solo é **analógico** e o Pi **não tem ADC** | ADC I2C (ADS1115) — ver doc de hardware |
| 4 | Volume de `Reading` cresce rápido | Índices desde já; rollups/particionamento como evolução |
| 5 | pH/NPK confiáveis são caros | Modelados como `kind` + entrada manual até haver sonda |

---

## Requisitos de hardware

Ver documento dedicado: [`docs/hardware/requisitos-minimos.md`](../hardware/requisitos-minimos.md).

## Glossário

- **Posto (station):** unidade física de cultivo — uma planta + sua câmera + seus
  sensores + seus atuadores. É a unidade de comparação.
- **Vigor:** métrica de crescimento derivada da foto (altura, área verde, folhas).
- **Receita:** conjunto de condições ambientais aplicadas a um posto, comparado
  contra o resultado (vigor + marcos) em um `Experiment`.
