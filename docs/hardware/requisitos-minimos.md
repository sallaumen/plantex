# Plantex — Requisitos Mínimos de Hardware

> Documento de refinamento de hardware para o MVP do Plantex.
> Planta de referência dos exemplos: **tomate-cereja**. Cultivo genérico.

Plantex tem duas metades físicas: o **servidor** (roda o Phoenix + Postgres + a
análise de imagem) e o **posto** (station) — um Raspberry Pi rodando o firmware
Nerves, com os sensores/atuadores/câmera de **uma** planta.

---

## 1. Servidor (o "cérebro")

Roda no Mac do Lucas (ou qualquer máquina Linux/macOS na mesma rede).

| Item | Mínimo | Observação |
|---|---|---|
| CPU | 4 núcleos | análise de imagem (vigor) roda aqui, não no Pi |
| RAM | 8 GB | Postgres + Phoenix + pipeline de visão |
| Disco | 20 GB livres + crescimento | fotos diárias acumulam; ~1–5 MB/foto/posto/dia |
| Rede | LAN com o Pi (Wi-Fi 2.4 GHz serve) | Channels sobre a rede local |
| SO | macOS ou Linux | já é o ambiente dos outros projetos |

**Não** precisa de GPU: o pipeline de vigor é determinístico (OpenCV/Nx), como no
`camerex`.

---

## 2. Raspberry Pi 3B — o que você já tem

| Spec | Valor | Impacto no Plantex |
|---|---|---|
| SoC | Broadcom BCM2837, quad-core Cortex-A53 @1.2 GHz | folgado para ler sensores + capturar foto |
| RAM | 1 GB | **suficiente** porque a visão roda no server |
| Wi-Fi | 2.4 GHz b/g/n | conecta ao server por Channels |
| GPIO | 40 pinos (I²C, SPI, UART, 1-Wire) | barramento dos sensores/relés |
| Câmera | 1× conector CSI | 1 câmera CSI **ou** webcam USB |
| USB | 4× USB 2.0 | webcam USB, sonda RS485 (futuro) |
| Armazenamento | microSD | firmware Nerves |

**Veredito:** o 3B é **mais que suficiente** para um posto no MVP, justamente
porque o desenho manda a visão computacional para o servidor. Ele só lê sensores,
aciona relés e sobe fotos.

### ⚠️ Detalhe crítico: o Raspberry **não tem entrada analógica (ADC)**

O sensor de umidade de solo capacitivo é **analógico**. O Pi não lê analógico
direto. É obrigatório um **conversor ADC** entre o sensor e o Pi:

- **ADS1115** (I²C, 16 bits, 4 canais) — recomendado; casa com `circuits_i2c` e já
  serve os sensores analógicos futuros.
- Alternativa: MCP3008 (SPI, 10 bits).

Sensores digitais/I²C (SHT31, DHT22, BH1750, DS18B20) **não** precisam de ADC.

---

## 3. Sensores do MVP (bill of materials por posto)

| Sensor | Mede | Interface | Precisa ADC? | Preço aprox. (R$) |
|---|---|---|---|---|
| **SHT31** (recomendado) ou DHT22/AM2302 | temperatura + umidade do **ar** | I²C / 1 pino | não | 25–70 |
| **Capacitivo v1.2** | umidade do **solo** | analógico | **sim (ADS1115)** | 15–25 |
| **ADS1115** | ADC para o(s) sensor(es) analógico(s) | I²C | — | 25–40 |

> SHT31 é mais estável e preciso que o DHT22; se o orçamento apertar, o DHT22
> resolve o MVP.

---

## 4. Sensores futuros (já modelados no software, sem compra agora)

| Sensor | Mede | Interface | Nota |
|---|---|---|---|
| BH1750 | luz (lux) | I²C | barato (~R$25), entra fácil |
| DS18B20 (à prova d'água) | temperatura do **solo** | 1-Wire | ~R$20 |
| Sonda de **pH** contínua | pH do solo | analógico (ADC) | confiável = caro (R$300–800+), exige calibração |
| Sonda **NPK RS485** | N-P-K aproximado | UART/RS485 (USB) | R$400–900, leitura aproximada |

Enquanto não houver sonda, **pH e NPK entram como leitura manual** (kit de teste
barato) — o schema já aceita esses `kind` de sensor.

---

## 5. Atuadores e relés (para os modos `manual`/`auto`)

| Item | Função | Preço aprox. (R$) |
|---|---|---|
| Módulo relé opto-isolado 2 ou 4 canais | chaveia bomba/luz/ventilador | 15–30 |
| Mini bomba d'água submersível 5 V (ou peristáltica 12 V p/ dosagem) | irrigação | 15–30 (submersível) / 60–120 (peristáltica) |
| Luz de cultivo LED (opcional) | fotoperíodo | variável |
| Ventilador 5 V/12 V (opcional) | circulação de ar | 15–40 |

### Regras elétricas (não-negociáveis)

- **Nunca** alimente bomba/motor/luz pela GPIO do Pi. Use **relé + fonte externa**.
- **Terra comum** entre Pi, relé e fonte dos atuadores.
- Relé **opto-isolado** para proteger o Pi.
- Bomba/motor DC: prever **diodo de flyback** (proteção contra pico indutivo).
- Água e eletrônica separadas fisicamente; conectores/junções fora do alcance de respingo.

---

## 6. Câmera — e o risco nº 1 do projeto

Captura de foto **sob Nerves no rpi3** é a parte menos madura do stack. Duas rotas,
decididas no **spike da fase 1** antes de investir no resto:

| Rota | Prós | Contras |
|---|---|---|
| **Pi Camera (CSI)** | conector dedicado, boa qualidade | suporte de captura sob Nerves exige validação |
| **Webcam USB (UVC)** | fácil de trocar/posicionar | depende de suporte UVC no sistema Nerves |

Plano B se a captura no firmware se mostrar dolorosa: **captura dedicada** (webcam
USB tratada por um caminho fora do firmware) sobe a foto para o server. A decisão
sai do spike, com evidência real.

| Item | Preço aprox. (R$) |
|---|---|
| Pi Camera v2 (CSI) ou webcam USB simples | 50–150 |

---

## 7. Infra do posto

| Item | Preço aprox. (R$) |
|---|---|
| microSD 32 GB A1/A2 (firmware Nerves) | 30–50 |
| Fonte oficial 5 V / 2.5 A para o Pi | 30–50 |
| Fonte separada para atuadores (5 V/12 V) | 30–60 |
| Protoboard + jumpers + resistores (pull-up I²C etc.) | 30–50 |
| Caixa/estrutura do posto (opcional) | variável |

---

## 8. Orçamento estimado do MVP (1 posto, fora o Pi que você já tem)

| Bloco | Faixa (R$) |
|---|---|
| Sensores (SHT31/DHT22 + solo + ADS1115) | 65–135 |
| Atuadores (relé + bomba) | 30–60 |
| Câmera | 50–150 |
| Infra (SD, fontes, protoboard) | 120–210 |
| **Total aproximado** | **~265–555** |

---

## 9. Escalabilidade (postos e Pis adicionais)

- **1 câmera por posto** (decisão de design). Um Pi 3B tem **1 conector CSI** →
  câmeras extras no mesmo Pi = webcams **USB** (limitado pela banda USB 2.0).
- Vários sensores/relés cabem no mesmo Pi (I²C endereça vários dispositivos;
  GPIO sobra).
- Para **muitas plantas**, o caminho natural é **um Pi por posto** (ou por pequeno
  grupo) — o desenho de Channels/`Device` já é multi-device desde o início.
- O `Experiment` compara postos independente de estarem no mesmo Pi ou não.

---

## 10. Checklist de compra do MVP

- [ ] SHT31 (ou DHT22/AM2302) — temp/umidade do ar
- [ ] Sensor capacitivo de umidade de solo
- [ ] **ADS1115** (ADC I²C) — obrigatório para o sensor de solo
- [ ] Módulo relé opto-isolado (2 ou 4 canais)
- [ ] Mini bomba d'água + mangueira
- [ ] Câmera (Pi Camera CSI **ou** webcam USB) — validar no spike
- [ ] microSD 32 GB A1/A2
- [ ] Fonte 5 V/2.5 A (Pi) + fonte separada dos atuadores
- [ ] Protoboard, jumpers, resistores
