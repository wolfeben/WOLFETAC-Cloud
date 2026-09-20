# September plan grouping and grower-link assessment — 20 September 2026

Target: Pool_Sandbox / LIVE APMS.

**No plans have been split. No production orders were finished or reposted during this assessment.** The user questioned whether splitting would address the reported grower-dimension error. Plan correction remains on hold: the supplied error and current installed engine source now identify a separate vendor/dimension mapping defect.

## Confirmed live evidence

Read at 2026-09-20 10:41:12 UTC (18:41:12 Perth), using installed helper 0.1.0.20.

- The 50 dataset production orders 1207–1256 remain Released under five plans BP0068–BP0072.
- All 50 production-order Grower ID values and original receipt Source No. values match the intended existing vendor.
- Each vendor's actual Default Dimension for the configured GROWER CODE dimension is numeric: GRW-100 → 100, GRW-102 → 102, GRW-030 → 030, GRW-064 → 064, GRW-049 → 049.
- All 450 production output lines carry the matching grower dimension value. There are zero vendor-link or grower-dimension mismatches in this dataset snapshot.
- Every production order's Batch Plan No. agrees with the helper manifest.
- Output evidence remains 1,350 verified contributions, 106,956 output entries and 106,656 unique unit serials.

Baseline: `build/week-20260921-before-plan-split.json`. This is a projection of live page evidence, not a posting test.

The Core dependency metadata defines Production Order Grower ID as a lookup of Batch Plan Grower Vendor No. by **Prod. Order No.**. It does not select an arbitrary grower from the plan header. The live lookup values agree with the intended vendors even while ten batches share each plan.

## Requirement correction versus error diagnosis

The user clarified that a batch plan belongs to one **grower, block and day**. The original helper incorrectly grouped all ten daily deliveries under one plan. Fifty plans would meet the clarified operating requirement; that does not establish the grouping as the cause of the grower error.

The user supplied the error at 2026-09-20T10:42:19.6455151Z and a screenshot of Released Production Order **1221**. The error says `Grower GRW-030 has no vendor. Set the GROWER CODE dimension to GRW-030 on the grower's vendor card.` Its stack identifies Codeunit 50280 VendorNoForGrower, called from Codeunit 50271 WriteTransferReceipt. The helper's historical 19 September duplicate-pool-code failure on order 1207 is a different error.

The freshly downloaded installed Pool Master 2.0.0.2 source (20 September 18:34 Perth) confirms the fault:

- `_TAC Pool Prod Order Post_.Codeunit.al:76` assigns `GrowerCode := ProductionOrder."Grower ID"`. Core's Grower ID is a vendor number, so this supplies GRW-030.
- Line 79 passes that value to WriteTransferReceipt; line 349 calls `GrowerMgt.VendorNoForGrower(GrowerCode)`.
- `_TAC Pool Grower Mgt_.Codeunit.al:66` filters Vendor Default Dimension **Dimension Value Code** by that argument. It therefore searches for GROWER CODE = GRW-030, while the correct existing value is 030.
- The same incorrect value flows into the charge context. Bypassing only the ledger vendor lookup would leave the grower code and charge classification wrong.
- The current Dimension Management source also comments out reading the numeric grower dimension and assigns the header Grower ID in its production-header resolver. Review both entry points when fixing the contract.

Order 1221 correctly belongs to plan BP0069, grower GRW-030, block 030-BA and date 22 September. Its original receipt PREC-000097 identifies GRW-030. All nine production output lines have GROWER CODE = 030 and GROWER TYPE = I.

Recommended engine change: keep vendor account and grower dimension value separate. Resolve the existing vendor's configured default dimension (the engine already exposes GrowerCodeForVendor), validate agreement with the production-line dimension, and pass the numeric dimension to the ledger/charge context. Retain the vendor number where the Pool table expects a Vendor No. Do not replace valid vendor dimensions with GRW-prefixed account numbers or merely strip a prefix. No engine change has been made here.

The 20 September source differs from the 18 September download despite both declaring version 2.0.0.2: the earlier production resolver passed the dimension-derived GrowerCode; the current one explicitly assigns Grower ID. This difference explains why a previous source review cannot stand in for today's installed code. The author of that change has not been identified.

Source archive: `C:\Users\BenL\Downloads\TAC Pool Master_DIY-ERP_2.0.0.2 (3).zip`, SHA-256 `EFD436A6F76458091AE91380FC4D2A813B36C6CCF038FF1082ACF758EE7C1E8A`. Relevant unmodified source copies are under `build/engine-source-20260920/`.

## Prepared helper update — not executed

Helper 0.1.0.20 was compiled and its installation completed in Pool_Sandbox on 20 September. It adds read-only vendor/default-dimension/production-link evidence, corrects future plan preparation to one delivery per plan, and exposes a guarded September-only plan-rearrangement action.

The rearrangement action **has not been invoked**. It would retain five existing plans, create 45 additional headers, and move the matching grower, lot and outlet rows while keeping batches/orders 1207–1256, receipt references and all posted entries. It rejects changed mappings, finished/pooled orders, unexpected child rows or a partially rearranged dataset. All writes share one transaction. No engine modification, ledger write, production finish, batch renumbering or functional pooling test is included.

Do not run the rearrangement as a supposed fix for the grower error. The failing lookup is now identified; follow the user's latest direction about whether they still want the separate plan-layout correction applied.

Build: successful; existing AL1025 warning for ignored `build/order-1207-ui.txt` only. Package SHA-256: `5EC16FF32B9BDDF7C14867BB6E8F08A9DBB25DE7999DC3C2B2B15A9FCC6526A3`.
