# 🌱 Plantex

App de **horticultura de precisão** em Elixir/Phoenix para acompanhar, controlar e
**comparar o crescimento de plantas** — medindo o ambiente por sensores, tirando
fotos diárias (time-lapse) e cruzando tudo em gráficos para responder:

> _Qual combinação de condições faz esta planta crescer melhor?_

Cultivo **genérico** — serve para qualquer planta. Exemplo canônico da documentação:
**tomate-cereja**. 🍅

## Estrutura (monorepo poncho)

```
plantex/
├─ core/       # Elixir puro — contratos compartilhados (sem Phoenix/Nerves)
├─ server/     # Phoenix + Postgres + LiveView (roda no Mac/servidor)
├─ firmware/   # Nerves (target rpi3) — roda no Raspberry Pi 3B
└─ docs/       # design + requisitos de hardware
```

- **Servidor:** UI, banco, gráficos, comparação, motor de regras, análise de imagem.
- **Firmware (Nerves):** lê sensores e aciona relés via `Circuits`, captura foto,
  fala com o servidor por Phoenix Channels.

## Documentação

- [Design / refinamento](docs/specs/2026-07-06-plantex-design.md)
- [Requisitos mínimos de hardware](docs/hardware/requisitos-minimos.md)

## Status

Em refinamento — design aprovado, plano de implementação a seguir.
