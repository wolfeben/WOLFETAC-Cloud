# WOLFETAC Cloud

Cloud-side Business Central per-tenant extension for WOLFETAC.

The first delivery focus is the SAL Stock & Logistics module. FruitBank remains reserved in this app and object range until its implementation scope is approved.

## Primary SAL pages

- Page 58006 — SAL Stock & Logistics Monitor
- Page 58007 — SAL Stock & Logistics Planner

The on-premises Packing Wall, Packing Facility Operator, scanner and physical pallet execution remain outside this Cloud extension.

## Repository structure

- `SAL/` — SAL architecture and AL source by object type.
- `FruitBank/` — reserved FruitBank source area.
- `docs/` — setup, object registry, decisions and acceptance criteria.
- `.github/copilot-instructions.md` — implementation guardrails for GitHub Copilot.
- `CLAUDE.md` — independent review instructions.

Start with [project setup](docs/PROJECT-SETUP.md), then read the [SAL architecture boundary](SAL/ARCHITECTURE.md) and [object ID registry](docs/OBJECT-ID-REGISTRY.md).

## Status

The app identity and object range are assigned. No production AL objects have been published from this project yet.
