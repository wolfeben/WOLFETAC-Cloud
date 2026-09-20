# Pool engine local source assessment

20 September 2026 | TAC Pool Master, DIY-ERP | Pool_Sandbox / LIVE APMS

**Review only. No corrective engine changes, compilation, deployment, production finishing, pool closing or payment posting were performed for this source import and assessment.**

## Conclusion

The reported production-order error is explained by a vendor-account/grower-dimension mismatch in the installed engine source. The existing vendor is linked correctly in the recorded sandbox evidence. The engine passes vendor account `GRW-030` into a lookup that expects its configured grower dimension value `030`.

This can be corrected in code. Changing the client's valid vendor dimension to `GRW-030`, or splitting the batch plans, does not address the underlying contract mismatch. Related posting and diagnostic paths also need review before presenting a complete fix. The separate pool-code collision remains in this source and may become the next blocker.

## Imported source and preservation

- Canonical project: `D:\WOLFETAC\Cloud\TACPoolMaster`.
- Source: `C:\Users\BenL\Downloads\TAC Pool Master_DIY-ERP_2.0.0.2 (3).zip`, downloaded from Pool_Sandbox on 20 September 2026 at 18:34 Perth.
- Archive SHA-256: `EFD436A6F76458091AE91380FC4D2A813B36C6CCF038FF1082ACF758EE7C1E8A`.
- App ID: `7ce03a80-b797-4aac-af41-7eaa96351ca5`; declared version `2.0.0.2`.
- All 130 exported AL files were copied into the canonical project and verified byte-for-byte by SHA-256. They have not been edited to fix the findings below.
- The manifest was imported with only generated `build` metadata removed. Version and dependencies were retained. The exported launch configuration was not imported; existing local launch settings were preserved.
- Previous source backup: `D:\WOLFETAC\.snapshots\TACPoolMaster-before-local-import-20260920-185218.zip`.
- Two pre-existing supplementary local AL files are absent from the cloud export and remain unchanged: `_TAC Ripening Price List_.Page.al` and `TACPoolTableRead.PermissionSet.al`. Consequently the whole local project is not an exact cloud build input. These files must be reconciled before any future build or deployment.
- An earlier source download declared the same version but contained different code. Use the archive hash and export date to identify this baseline, not the version alone. Historical local packages have not been rebuilt from this import.

## Evidence for production order 1221

The user's error at `2026-09-20T10:42:19.6455151Z` identifies `VendorNoForGrower` in codeunit 50280, called by `WriteTransferReceipt` in codeunit 50271. The supplied screenshot identifies released production order **1221**.

The earlier read-only live snapshot at 10:41:12 UTC recorded the following:

| Field | Recorded value |
|---|---|
| Production order / plan | 1221 / BP0069 |
| Plan date / block | 22 September 2026 / 030-BA |
| Production-order Grower ID | GRW-030, the existing vendor account |
| Original receipt / Source No. | PREC-000097 / GRW-030 |
| Configured grower dimension | GROWER CODE |
| Vendor default dimension value | 030 |
| All nine output-line grower dimensions | 030; grower type I |

The same snapshot found matching vendor links and grower dimensions across all 50 dataset orders and 450 production lines. The five vendor mappings were `GRW-100 → 100`, `GRW-102 → 102`, `GRW-030 → 030`, `GRW-064 → 064`, and `GRW-049 → 049`.

Core's production-order Grower ID looks up Batch Plan Grower Vendor No. by **Prod. Order No.** It does not pick an arbitrary grower from the shared plan header. Plan grouping is a separate operational requirement.

Evidence files: `D:\WOLFETAC\Cloud\PoolE2E\build\week-20260921-before-plan-split.json` and `D:\WOLFETAC\Cloud\PoolE2E\WEEK-20260921-PLAN-ASSESSMENT.md`. These describe an earlier live snapshot, not a fresh execution of posting during this assessment.

## Findings for the development team

Line numbers refer to the imported 20 September source. Source findings below have not been exercised through financial posting in this assessment.

| Area | Finding and consequence | Evidence / confidence |
|---|---|---|
| Production finishing | Vendor account is assigned to GrowerCode and passed to a dimension-to-vendor lookup. For order 1221, it searches for dimension value GRW-030 instead of 030 and raises the reported error. The same value also enters the charge context. | **Observed error, supported by live mapping evidence and source.** `_TAC Pool Prod Order Post_.Codeunit.al` lines 76, 79–80, 348–349, 370; `_TAC Pool Grower Mgt_.Codeunit.al` line 66. |
| Production diagnostics | The header dimension resolver likewise assigns Grower ID to GrowerCode; the diagnostic then resolves it as a grower dimension. It can direct the user towards changing already-correct vendor setup. | **Source-confirmed mismatch; diagnostic not executed.** `_TAC Pool Dimension Mgt_.Codeunit.al` line 27; `_TAC Pool Post Diagnostic_.Codeunit.al` line 162. |
| Consignment and invoice posting | Consignment Grower No. has a Vendor relation but is copied into GrowerCode and passed to ledger/charge paths. The same variable is also used for pool ownership, which correctly expects a vendor. A blanket replacement would break that use. | **Source-confirmed identity mixing; runtime impact depends on the posting path and charges.** `_TAC Consignment Line_.Table.al` line 71; `_TAC Pool Consignment Post_.Codeunit.al` lines 113, 476, 602, 610, 618–622, 775–787. |
| Pool-close charges | Pool Grower No. is assigned to charge-context Grower Code. The shared charge engine resolves that field as a dimension value. | **Source-confirmed incompatible input; pool close not executed.** `_TAC Post Pool_.Codeunit.al` lines 135, 149; `_TAC Pool Charge Engine_.Codeunit.al` line 274. |
| Reconciliation | Production and credit dimension wrappers leave their Grower output unset; invoice and consignment wrappers assign a vendor account instead. Season/PoolWeek outputs are also no longer populated by the shown resolver calls. Expected-charge and source-group resolution need review alongside actual posting. | **Source-confirmed incomplete/inconsistent resolver outputs; reconciliation outcomes not tested.** `_TAC Pool Reconciliation_.Codeunit.al` lines 577–618. |
| Pool identity, separate issue | FindOrCreate distinguishes group, variety, grade, size and grower, but GetPoolCode omits grade and size. A second grade or size can therefore require a new pool while generating the same primary key. The VGS key's Unique setting is commented out. | **Current source remains susceptible; an earlier duplicate-code failure was recorded separately.** `_TAC Pool_.Table.al` lines 139–141, 149–156, 168–188. Not re-executed for this review. |

## Proposed correction scope — not implemented

1. Keep vendor account and grower dimension value as separate variables. Preserve the vendor account in Pool Grower No., consignment Grower No. and ledger Grower No.
2. Resolve the grower dimension through the existing `GrowerCodeForVendor` procedure in codeunit 50280 (line 51), using the configured dimension and actual vendor default. Do not infer it by stripping `GRW-`; leading zeros and other vendor numbering must remain valid.
3. Check the source grower dimension agrees with the intended vendor and that reverse mapping resolves uniquely to that vendor. Use the dimension value consistently in ledger Grower Code and charge contexts.
4. Apply the same identity contract to production, diagnostics, consignment/invoice, pool-close charges and reconciliation. Fixing only the failing lookup would leave inconsistent downstream values.
5. Address pool identity allocation separately, preserving existing references and aligning a concurrency-safe unique identifier/business key with the full logical pool identity.

Before a future release, validation should cover leading-zero growers, arbitrary vendor numbers, missing/ambiguous mappings, conflicting source dimensions, affected charge paths, reconciliation and multiple grades/sizes for one grower/week. No such functional tests were run here. This is a focused grower-identity review, not a full certification of the engine or its payment calculations.
