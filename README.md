# WOLFETAC Cloud

Cloud-side Business Central per-tenant extension for WOLFETAC.

The first delivery focus is the SAL Stock & Logistics module. FruitBank now has an isolated first API slice for TAC-managed portal sites; its later stock and workflow scope remains separate from SAL.

## Primary SAL pages

- Page 58006 — SAL Stock & Logistics Monitor
- Page 58007 — SAL Stock & Logistics Planner

The on-premises Packing Wall, Packing Facility Operator, scanner and physical pallet execution remain outside this Cloud extension.

## Repository structure

- `SAL/` — SAL architecture and AL source by object type.
- `FruitBank/` — isolated FruitBank APIs, administration and implementation notes.
- `docs/` — setup, object registry, decisions and acceptance criteria.
- `.github/copilot-instructions.md` — implementation guardrails for GitHub Copilot.
- `CLAUDE.md` — independent review instructions.

Start with [project setup](docs/PROJECT-SETUP.md), then read the [SAL architecture boundary](SAL/ARCHITECTURE.md) and [object ID registry](docs/OBJECT-ID-REGISTRY.md).

## Status

The app identity and object range are assigned. The FruitBank `portalSites` slice is implemented locally but no production AL objects have been published from this project yet.
