# GitHub Copilot instructions for WOLFETAC Cloud

## Scope and authority

Implement only the bounded issue or acceptance criteria supplied for the current branch. Do not invent business rules, silently broaden SAL scope, or modify the on-premises project from this repository.

Read these files before writing AL:

- `SAL/ARCHITECTURE.md`
- `docs/OBJECT-ID-REGISTRY.md`
- `docs/PROJECT-SETUP.md`

## AL requirements

- Use only IDs reserved for the correct domain and object type.
- Never reuse or renumber a published object.
- Follow `NoImplicitWith` and Cloud-compatible AL; do not use .NET or direct SQL.
- Add captions, tooltips and correct `DataClassification`.
- Keep permissions least-privilege and provide explicit permission sets.
- Use `Validate`, supported Business Central codeunits and events for source-document changes.
- Never insert or modify Item Ledger Entry, posted shipment, posted receipt or other posted tables directly.
- Do not hard-code customer, location, item, marketer, capacity or environment values.
- Do not infer TAC or Costa from customer or display-name text.
- Keep UI pages thin. Put validation, versioning, integration and posting orchestration in testable codeunits.
- Make integration handlers idempotent and version-aware. Do not mark a plan delivered until receipt is acknowledged.
- Preserve Standard, Custom and Mixed pallet semantics. A custom pallet sequence represents one physical pallet and may contain multiple exact components.
- Do not treat Unconsigned stock as an order.
- Do not treat Packing Complete as shipment, transfer receipt or invoicing completion.

## Quality gate

For every feature:

1. update or confirm acceptance criteria;
2. add tests for successful, invalid and repeated/idempotent cases;
3. compile without errors;
4. review the staged diff for credentials, generated symbols and compiled apps;
5. state any assumption that needs business confirmation;
6. publish only to the TestProd sandbox when explicitly requested.

Do not add demo records or browser-only actions to production objects.
