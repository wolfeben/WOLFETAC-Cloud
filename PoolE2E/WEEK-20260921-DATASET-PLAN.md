# Pooling test dataset: 21–27 September 2026

Status: requested and quantities confirmed; no BC records created for this dataset yet.
Destination: Pool_Sandbox / LIVE APMS (existing task destination).

Helper version 0.1.0.7 was installed successfully in Pool_Sandbox on 18 September 2026. Page/codeunit 59352 provides a read-only setup snapshot and uses the normal user's table read permissions and existing sandbox/company guard. The snapshot was read at 2026-09-18 04:32:45 UTC and explicitly confirmed company LIVE APMS. No delivery, production, pallet or ledger records for this dataset have been created.

## Live setup confirmed on 18 September

- All nine requested items exist, are unblocked, and have SIZE, GRADE and VARIETY defaults.
- All five growers exist as GRW-100, GRW-102, GRW-030, GRW-064 and GRW-049. Each has at least two mapped blocks.
- Existing open pool week WK-2026-13 covers exactly 21–27 September 2026. No batch plans existed in that date range at the snapshot time.
- Batch-plan input item BIN-HASS; production location MANJIMUP; family FRUIT; batch numbering BATCHLINE and plan numbering BATCHPLAN.
- Six tray items use base TE, pallet quantity 160 and a KG factor of 5.4. Their label tags are 0025, 0023, 0020, 0225, 0223 and 0220.
- PKD-HABKGL1KPR uses base BK, pallet quantity 96, KG factor 9.8 and tag 3700.
- PKD-HAKGMXPG uses base BK, KG factor 1, configured PALLET quantity 94 and tag 6400. The requested 440 kg pallet is therefore different from the configured pallet quantity.
- PKD-HABKBN1KPP uses base BK, KG factor 9.8, configured PALLET quantity 96 and tag 6700. A user clarification is pending: retain 440 kg with fractional baskets, use 45 baskets (441 kg under the pool engine's multiplication), or use 96 baskets (940.8 kg under that multiplication). Do not silently change item UOM setup. The standard BC UOM conversion convention must also be reconciled with the pooling engine's multiplication before posting KG quantities.
- All nine items use LOTALL. Lot tracking is enabled; SN-specific/manufacturing serial tracking is not required. The requested serials still need to be recorded through the supported tray/pallet workflow; do not turn serial tracking on for existing items merely for this dataset.
- Pallet auto-output posting is enabled, using OUTPUT / ONPREMTEST. Do not delete or reuse unrelated journal lines.
- General Ledger posting window covers the requested dates (30 June 2026 to 30 June 2027).
- Extension Management shows Avocados Core 1.0.1.5 (Dev) with its Uninstall action enabled and Install disabled. Its Download Source action explicitly rejects downloading under the package's effective policies. Older accessible source is reference only; the current implementation has not been source-verified.
- Extension Management confirms TAC Pool Master 2.0.0.2 (Dev) is installed. A fresh source download on 18 September has SHA-256 BA5C9A28F453F5BF2CAD61EE473B679775F5BB040001C7F37586D118B2718BAD. Every nonempty entry was compared with the 17 September download (B3FC5E9E64B345242B9A82C9698CAF2CA65E652EBD444193D04677A086BE3307); only `_TAC Trans. Orders Ext._.PageExt.al` and `app.json` changed. The pool identity allocation and production-close code therefore remain as previously reviewed. This is a source comparison, not a successful execution of the requested multi-product dataset.

Proposed existing blocks, subject to validation at creation: 100-A / 100-BE; 102-A / 102-B; 030-BA / 030-BB; 064-A / 064-B; 049-A1 / 049-B. Use the same two blocks for each grower's five daily deliveries unless the user requests otherwise.

`Prepare-WeekDataset.ps1` produces a draft JSON manifest, validates 50 deliveries, 909 unique proposed pallet IDs and 106,656 required unit serials, and assigns all 50 orders to each mixed pallet. It is an offline planning script: no identifiers are reserved and no BC writes occur. Actual serials are deliberately not generated until the real batch numbers and current parser are known. The fractional-basket question remains unresolved; the draft retains the user's original 440 kg request.

## Confirmed requirements

- Five daily batch plans dated 21, 22, 23, 24 and 25 September 2026.
- Growers 100, 102, 030, 064 and 049; retain leading zeros and resolve exact existing vendor IDs.
- Two distinct existing blocks per grower; one 10-bin delivery per block per day.
- 50 deliveries, 500 bins, 50 production orders: one order for each delivery.
- Create consumption journals before changing Firm Planned orders to Released, following the supported installed workflow.
- Complete all output before changing Released orders to Finished; finishing must invoke the installed pooling engine.
- Unique lot and pallet identifiers; unique numeric 24-character serials for each unit on unit-counted pallets.
- Additional mixed pallet for each of the nine items, with output from all 50 production orders. Unequal whole-unit contributions are permitted.

| Item | Pallets per order | Quantity per pallet | Extra mixed pallet quantity |
|---|---:|---:|---:|
| PKD-HATYGL25PR | 2 | 160 units / serials | 160 units |
| PKD-HATYGL23PR | 2 | 160 units / serials | 160 units |
| PKD-HATYGL20PR | 2 | 160 units / serials | 160 units |
| PKD-HATYAV25C1 | 2 | 160 units / serials | 160 units |
| PKD-HATYAV23C1 | 2 | 160 units / serials | 160 units |
| PKD-HATYAV20C1 | 2 | 160 units / serials | 160 units |
| PKD-HABKGL1KPR | 2 | 96 units / serials | 96 units |
| PKD-HAKGMXPG | 2 | 440 kg | 440 kg |
| PKD-HABKBN1KPP | 2 | 440 kg | 440 kg |

Expected totals: 900 regular pallets + 9 mixed pallets = 909 pallets. Each item has 101 pallets. Each of the six 160-unit products totals 16,160 units; the 96-unit product totals 9,696 units. Together these require 106,656 unique serials. Each bulk product totals 44,440 kg (88,880 kg combined), in addition to the packed products' actual item-derived kg.

## Required live checks before creation

- Confirm current installed Core/Pool Master versions and source, exact company, existing pool week/date boundaries, production location, receiving and journal setup.
- Read each real item's default dimensions, base/TE/KG units, tracking setup and numeric four-character label tag. Validate that normal document creation inherits required dimensions; do not replace missing setup with guessed synthetic values.
- Resolve two valid blocks per grower and the configured bin item and bin weights. Reconcile requested output kilograms against input; no invented bin weight or silent quantity changes.
- Verify allowed posting dates, available batch numbers, delivery numbering and collisions against existing lots/pallets/serials.
- Confirm serial parser contract against installed source. The older inspected Core export reads product from characters 1–4, batch from 5–8 and Julian day from characters 14–16 of a 24-character serial, with year from WorkDate. Do not assume all versions share this contract.
- Confirm how kg-only output is posted and how lot and pallet identity are represented by the supported routines. Mixed pallets must retain each source order/grower, rather than assigning the entire pallet to one order.
- Confirm whether consumption is only prepared or may also be posted before release in the installed customization. Preserve the user's requested sequence without bypassing status validation.
- Inspect outbound synchronization hooks before running creation: this task authorizes sandbox data, not exports to production or messages to third parties.

## Execution and evidence

Use supported bin receipts, batch-plan generation, status changes, item tracking and journal posting. No direct inventory/pool ledger inserts and no pooling-engine fixes. Retain a run manifest that maps delivery, date, grower, block, batch, order, item, pallet, lot and serial range. Reconcile each completed stage and resume only missing work; do not blindly replay partially posted batches.

Mixed allocation target: 160-unit pallets give 3 units to every order plus 1 to ten orders; the 96-unit pallet gives 1 to every order plus 1 to 46 orders. Rotate remainder assignments deterministically. Each 440-kg mixed pallet gives 8.8 kg to every order, subject to the real item's supported precision.

Validate receipt/consumption quantities, all 909 pallet totals, unique serials and source attribution, finished output, order status and pool-ledger quantities/charges. Report successful checks, expected exclusions, actual engine failures and unexecuted stages separately. A grade/size collision must remain recorded as an engine rejection, not bypassed.
