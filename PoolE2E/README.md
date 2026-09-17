# Pooling end-to-end test data

Target: **Pool_Sandbox / LIVE APMS only**. Page **59350 — Pooling E2E Test Bench**.

The dataset has been created. **Do not select Create test dataset again.** Open [the test bench](https://businesscentral.dynamics.com/d000c867-fb80-4af4-9cc1-3655530c967e/Pool_Sandbox?company=LIVE%20APMS&page=59350) and read the [17 September results and team handover](RUN-RESULTS-20260917.md) before running further steps. In the pooling overview, choose season **ZE2E**.

This separate helper creates synthetic source documents and runs the installed BC and TAC Pool Master posting routines. It does not insert or repair inventory, general, customer, vendor or pool ledger entries. The overview and pooling engine are unchanged.

## Dataset

All test pools use season `ZE2E`. Pool week codes are `ZE2E-W01` through `ZE2E-W09`. Their batch dates are chosen after the latest existing pool week, starting on a Monday. Posting uses the current date, subject to BC's existing posting restrictions. This deliberate separation avoids overlapping the engine's date-based week lookup.

- Growers/vendors `ZE01`–`ZE10`, buyer `ZE2E-CUST`, location `ZE2E`.
- Raw item `ZE2E-BIN`, packed item `PKD-ZE2E`, dedicated lot tracking `ZE2E-LOT`.
- Packed base unit KG; TE contains 6 KG. Raw input is one BIN per 100 KG; this is a fixture assumption, not a packing-yield specification.
- Fractional-bin cases can trigger BC's normal “some consumption is still missing” finish confirmation because production component planning rounds bins. The runner posts the fixture's declared actual consumption, and the confirmation is reviewed interactively. These tests validate pooling from actual output; they do not certify production BOM yield or complete planned component consumption.
- Production batches/orders `Z201`–`Z211` are four characters for the engine's batch lookup. Ten receipt orders `ZE2E-P01`–`ZE2E-P10`; the repack has no bin receipt/consumption.
- Sales orders and consignments `ZE2E-S01`–`ZE2E-S04`, each with a test carrier manifest and freight leg.
- Test PKG template 593501: $0.60/TE, scoped to new variety ZE and pack type ZE2E. Existing eligible rules remain active. Existing templates and shared setup are not changed.
- Test freight: one pallet space at $50 plus 10% fuel = **$55** per consignment. The mixed-week shipment expects $22/$33 allocation under Units.
- Only posting-group codes are copied from existing masters. Real names, bank details, addresses, emails and integration identities are not copied.

## Run order and acceptance

Create the dataset once. Duplicate creation stops rather than overwriting records. Run packing cases, inspect every result, then run selected sales and financial steps. A prerequisite must be Completed before a dependent action runs. Close actions additionally require the group's sales to reconcile. Existing or partial payment headers block blind retries.

| Steps | Sources | Expected |
|---|---|---|
| 10, 20 | Z201, Z202 | Internal group: 600 + 400 KG; PKG -$60/-$40 |
| 30 | Z203 | External: 300 KG; PKG -$30 |
| 40 | Z204 | Contract pack: 120 KG; grower close must reject |
| 50, 60 | Z205, Z206 | 240/360 KG in different weeks for one invoice line |
| 70, 80 | Z207, Z208 | Same grower/week, different grade: separate 100/80 KG pools |
| 90 | Z209 | 60 KG unpriced; provisional must reject with current setup |
| 100 | Z210 | Missing SIZE: reject finish for that specific reason |
| 110 | Z211 | Repack output without bins: no TR |
| 200, 210 | ZE2E-S01, S02 | 600 KG/$1,800 and 400 KG/$1,200 PR, excluding tax; FR -$55 each |
| 220 | ZE2E-S03 | 300 KG/$1,200 PR; FR -$55 |
| 230 | ZE2E-S04 | One 600 KG/$3,000 invoice line; $1,200 week 4 / $1,800 week 5; FR -$22/-$33 |
| 300 | Engine expense | -$60/-$40 expense split, no KG |
| 310 | Engine adjustment | -10/+10 KG, group total unchanged |
| 400–440 | Engine closes | Internal cumulative 40%, 80%, final; external 50%, final under current setup |
| 450, 460 | Negative close cases | Contract-pack and unpriced close rejection; verify exact reason and no partial payment |
| 500, 510 | Duplicate processing | No additional ledger rows, KG or dollars |
| 600–620 | Manual acceptance | Credits/reversal policy, customer/vendor applications, reports and source links |

**Completed is a limited automated checkpoint**, not full accounting approval. Packing checks output/TR quantity and the controlled PKG charge; sales checks total PR kg/value, consignment kg, total FR dollars and the per-pool PR split on the mixed case. Close checks payment count/completion metadata. Independently reconcile other charges, freight allocation by pool, GST, posting accounts, supplier documents and settlement amount. Negative-test exceptions remain Blocked until their actual reason is reviewed; an unrelated setup error must never count as a successful rejection.

The unpriced fixture currently has unsold production and no consignment. It must be supplemented with a successfully shipped unpriced consignment to test a policy defined specifically around consignment fruit payments. Its observed G/L setup error does not prove the intended unpriced guard worked. Expense completion currently verifies that the engine returned successfully; independently compare the posted source rows and dollar split, as in the run report.

The helper does not automatically reverse payments, apply bank/customer/vendor entries or enable invoice credits. Those are explicit manual acceptance steps, with source records created by the preceding steps. No bank export or external transfer is part of this fixture.

## Known candidate engine failures

The September 17 sandbox source uses shipment allocation Source Line No. 0 while invoice revenue looks up the nonzero shipment line. Tests retain that mismatch instead of repairing it. Grade/size are omitted from generated pool codes; step 80 can expose a key collision. Mixed-week source attribution is not fully covered by the overview's current invoice checks.

## Build and provenance

Run `Build.ps1` to compile the helper. It uses local Microsoft 28.3 symbols and public contracts from TAC Pool Master 2.0.0.2 / Core 1.0.0.41; execution invokes the currently installed sandbox extensions. The compiler success is not evidence of server execution or accounting correctness. Installed package/version evidence and run results are recorded separately for each deployment.

App ID: `73d8df71-2874-4c7f-9ae3-ea20b8d21f04`. Objects 59350–59399 reserved; only 59350/59351 currently used. Standard permissions apply; the helper does not elevate posting permissions. No install/upgrade trigger creates data. Only the explicit page actions do so, after checking environment and company.

Posted test transactions are not deleted by the helper. Keep the manifest and normal BC audit trail; use supported reversals if cleanup is later approved.
