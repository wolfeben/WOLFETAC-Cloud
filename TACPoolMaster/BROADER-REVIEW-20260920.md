# Pool engine: additional source review

20 September 2026 | TAC Pool Master by DIY-ERP, declared version 2.0.0.2

**Review only. No AL source was changed, no package was built or published, and no sandbox transactions or functional tests were run.**

## Assessment

There are material issues beyond the reported grower lookup and pool-code collision. The highest priorities are credit reversals, shipment ownership and quantities, invoice allocation, unit conversion, and the signs used for grower settlements and G/L posting. Several checking/reporting paths can also conceal or misdescribe those problems.

This review traces the imported production, consignment, shipment, invoice, credit, charge, close, G/L, reconciliation, adjustment, expense and report code, including the page actions that call it. Findings describe defects in this source and the conditions that activate them. **They do not establish that a particular historical payment or invoice is wrong.** Numerical examples are desk calculations, not results from executing BC.

Baseline: local Git commit `5613b6d`; installed Pool_Sandbox source export downloaded on 20 September 2026. Archive SHA-256: `EFD436A6F76458091AE91380FC4D2A813B36C6CCF038FF1082ACF758EE7C1E8A`. All 130 exported AL files were imported unchanged. Two retained local supplementary AL files are outside that export. See [baseline and grower assessment](LOCAL-ASSESSMENT-20260920.md) for provenance and the previous live evidence.

P1 means correct before relying on the affected posting/payment path. P2 means a workflow, diagnostic or reporting defect that also needs correction. Confidence is **source-confirmed, not runtime-reproduced in this review**, unless explicitly stated otherwise. Effects can be masked by an earlier blocking error or depend on configured charges and the source documents used.

## Source reference key

All files are in `D:\WOLFETAC\Cloud\TACPoolMaster`. Line references below apply to this exact import.

| Short name | Local source |
|---|---|
| CONS | [_TAC Pool Consignment Post_.Codeunit.al](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool Consignment Post_.Codeunit.al>) |
| PROD | [_TAC Pool Prod Order Post_.Codeunit.al](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool Prod Order Post_.Codeunit.al>) |
| CHARGE | [_TAC Pool Charge Engine_.Codeunit.al](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool Charge Engine_.Codeunit.al>) |
| GROUP | [_TAC Pool Group Close_.Codeunit.al](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool Group Close_.Codeunit.al>) |
| POOL | [_TAC Post Pool_.Codeunit.al](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Post Pool_.Codeunit.al>) |
| GL | [_TAC Pool GL Posting_.Codeunit.al](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool GL Posting_.Codeunit.al>) |
| RECON | [_TAC Pool Reconciliation_.Codeunit.al](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool Reconciliation_.Codeunit.al>) |
| PREVIEW | [_TAC Pool Preview_.Codeunit.al](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool Preview_.Codeunit.al>) |

## Confirmed source findings

### F01 — Credit memos can be recorded as processed without reversing their value — P1

CONS 553–566 comments out both the assignment of negative proceeds and the construction of the credit charge context. The active code at 568 passes the still-zero `Proceeds` into `WriteCreditRevenue`; line 570 applies charges using an unpopulated context. `Reversal` is therefore not set. The parent procedure can still insert Credit Memo State at 521–528 after processing the line.

Trigger: credits are enabled, the applied invoice is recognised by pooling, and a credit line resolves to a consignment. A $100 credit then supplies $0 to the pool revenue writer, subject to later errors rolling back the transaction. Mandatory templates may instead block the credit; permissive templates can allow misleading completion state.

Suggested correction: resolve the original allocations, reverse the appropriate signed LCY amount and charge bases, populate the reversal context, and mark completion only after all required allocations succeed. Correcting this alone also requires F15's G/L sign correction. Future validation: full and partial credits, multiple source growers, foreign currency, and safe retry.

### F02 — Different growers can be merged into the first grower's shipment line — P1

CONS 375–381 finds an existing consignment line by consignment, shipment, week, season and item. It does not distinguish grower, batch, source shipment line or pool. Grower and pool are assigned only when that line is first inserted, at 392 and 398–399. Subsequent matching batches simply add quantity at 407.

Example: the same item/week is shipped from grower 030 and grower 049. Their quantities can end up on one consignment line retaining the first grower's identity. This is directly relevant to the requested mixed pallets.

Suggested correction: preserve source allocation by grower/pool and shipment line, with batch/lot evidence retained. Future validation: one mixed pallet, the same item from several growers, and several lines of the same item/week.

### F03 — Partial shipments use the original output quantity rather than the shipped quantity — P1

CONS 338–356 finds all output for the shipped lot/item and stores the production order/lot quantity in `BatchPallet.Quantity`. It does not cap or allocate this using the outbound entry quantity, serials or item application quantities. That full amount is added to the consignment at 407.

Example: produce 160 units on a pallet, ship 40, and the source calculation still collects 160. A subsequent partial shipment can count the same production output again. The code also reads base output quantities while labelling the consignment with the shipment UOM.

Suggested correction: derive contributions from the actual shipped quantities and their production applications/serial evidence, with explicit unit conversion. Future validation: 40 then 120 from one pallet, mixed batches, and a non-base sales UOM.

### F04 — Shipment source references can point to the wrong line or document type — P1

CONS 363/370 correctly records the current shipment line in `ShptLineNo`, but line 387 writes `ItemLedgerEntry."Document Line No."` after that earlier ledger loop has finished. It is not the current BatchPallet line. Line 384 also always writes Sales Shipment Line as Source Type, including the transfer-shipment branch.

The invoice revenue writer subsequently relies on Source No./Source Line No. at CONS 745–750. Incorrect references can omit a source or allocate an invoice against the wrong shipment evidence; they also affect uninvoiced-quantity checks.

Suggested correction: write the current source type and current shipment line, and include those identities in aggregation. Future validation: a shipment with at least two different lines, plus a transfer shipment.

### F05 — One invoice line can allocate its full value once per source shipment line — P1

CONS 744–758 loops through each distinct shipment line supporting an invoice line. Inside each iteration, it divides the **entire invoice-line** quantity and amount among that shipment line's consignment rows. It never first allocates the invoice total between the different shipment lines.

Example: an invoice line for $1,000 supported by two shipment lines can allocate $1,000 to each, producing $2,000 of pool revenue. This applies where a posted invoice line genuinely has more than one source shipment line; how often that occurs in this tenant needs checking.

There is also a definite residual-branch error: `CurrentLineNo` starts at zero, is compared with `LineCount` before incrementing, and therefore never reaches the final-row residual branch during a normal n-row iteration (753–766). No rounding is applied to the normal allocations.

Suggested correction: allocate the invoice's quantities/value once across all actual source contributions, round consistently and put the residual on the final allocation. Assert that totals equal the source invoice line. Future validation: multiple source shipment lines and a three-way monetary split.

### F06 — Invoice completion and charges do not require a complete, correct source allocation — P1

There are three connected gaps in CONS:

- `FindInvoiceConsignmentLine` falls back to the first line on the consignment when item/week/season matching fails (628–644).
- `WriteInvoiceRevenue` can finish without writing any revenue when no qualifying shipment/value-entry mapping exists (729–805). The caller still writes a Fruit Payment, applies charges and can mark the invoice processed (616–626 and 441–450).
- Invoice charges use one context based on the initially selected consignment line (620–622), even when revenue is distributed across multiple pools. The Fruit Payment is also assigned to that initial pool (673–698).

Suggested correction: make allocation return explicit success and exact totals; block or clearly queue unresolved sources. Allocate pool-specific charges and payment attribution consistently with the revenue instead of silently taking the first line. Future validation: a direct invoice without a shipment, a missing item match, and an invoice spanning two growers/pools.

### F07 — Kilogram conversion is reversed for standard BC item-UOM factors — P1

PROD 527–533 and `_TAC Consignment Line_.Table.al` 149–155 multiply quantity by `GetQtyPerUnitOfMeasure(Item, 'KG')`. For an item with a different base UOM, that factor is **base units per KG**, so base quantity must be divided by it. A consignment quantity in another UOM must first be converted to base units. The configured pool KG UOM is also bypassed by the literal `KG`.

Illustrative standard setup: 1 TE = 5 kg means the KG UOM contains 0.2 TE. For 100 TE, the current multiplication gives 20 kg; the corresponding conversion is 100 / 0.2 = 500 kg. This is a source defect against standard UOM semantics; actual affected item setup and transaction values have not been re-read or quantified here. Microsoft's [Item Unit of Measure definition](https://learn.microsoft.com/en-us/dynamics365/business-central/application/base-application/table/microsoft.inventory.item.item-unit-of-measure) confirms the factor's direction.

Suggested correction: one shared, validated conversion routine using source/base/target UOMs. Check existing item conversions before changing data or recalculating historical entries. Future validation: base KG, base TE with a fractional KG factor, alternate sales UOM, and missing conversions.

### F08 — Freight and revenue kilograms are counted again as pool movement kilograms — P1

Freight records copy kilograms at CONS 160; invoice revenue records copy kilograms at 792. GROUP 473–501, POOL 454–467 and the Pool table's Total Kilograms FlowField sum kilograms across all ledger transaction types.

A 100 kg production receipt, a 100 kg freight record and a 100 kg revenue record therefore contribute 300 to those totals, although only 100 kg was produced. These totals feed kilogram charges and allocation weights. If growers have different shipment/invoicing progress, their calculated shares can differ even when their production contributions are equal.

Suggested correction: keep source-document quantities for evidence, but calculate pool contribution kilograms using the defined movement types and their signed adjustments. Future validation: adding freight or an invoice must not increase contributed kilograms or change grower shares solely because that document was posted.

### F09 — Customer charge rates can silently resolve to zero — P1

CHARGE 351–364 only returns a customer-source rate for a ripening row. For other Customer-source rows it falls through to zero; it no longer reads the exposed Default Settlement Rebate Rate. In addition, the new ship-to lookup requires `DC Code`, but invoice context construction at CONS 807–834 never sets it. A normal nonblank Ship-to Code therefore is not used by that lookup.

Related eligibility issue: `RipenerConditionMet` calls `TestField("TAC Ripening Rate")` before checking the tray category (CHARGE 241–249), so evaluating a non-ripening condition can raise a missing-rate error instead of returning false.

Suggested correction: agree the authoritative rate source, implement every supported rate-source branch, populate ship-to identity from the posted source and distinguish a genuine zero rate from missing configuration. Future validation: rebate-only customer, nonblank ship-to, ripening and non-ripening fruit, and an intentional zero-rate exception.

### F10 — Dispatch runs the charge engine without building a charge context — P1

`DespatchConsignment` calls `PostConsignmentLines(..., true, false)` at CONS 37. In that procedure, only `BuildConsignmentContext` is conditional on `Post`; `ApplyCharges` at 122 runs unconditionally. On dispatch, the context is therefore empty.

Depending on templates, this can block dispatch with a misleading mandatory-template error or write zero/unassigned charge entries. Suggested correction: align context construction and charge execution with the intended trigger, and reject unpopulated posting contexts. Future validation: dispatch alone, then consignment posting, confirming each intended charge appears exactly once with its source and pool.

### F11 — Mandatory destination rules are checked against a blank grower — P1

`ValidateConsignmentLines` reads `ConsignmentLine."Grower No."` inside the freight-leg/rule loop before fetching any ConsignmentLine (CONS 74–84). Normal mandatory rules therefore attempt a lookup for blank grower rather than checking each actual grower travelling to that destination.

Suggested correction: validate the applicable destination rules for every distinct source grower and use the actual despatch date. Future validation: two growers, two legs, one valid accreditation and one missing/expired accreditation. This finding does not assume what accreditation rules the client ought to configure.

### F12 — An ambiguous charge-template match can become silently accepted — P2

CHARGE 176–183 sets `IsAmbiguous` when two equally specific grower-filtered rows tie, but a later equally specific row without a grower filter sets it back to false while retaining the same winner. The two tied winning rows still exist.

Example order: A filters Grower 030; B also filters Grower 030 with a different rate; C filters Variety HA. All match, all have one filter. A/B should remain ambiguous, but C can clear the error. The table does not enforce uniqueness of filter combinations.

Suggested correction: preserve ambiguity for the current highest precedence until a strictly superior candidate replaces the tied set. Future validation: the same eligible rows in different ID/order arrangements produce the same result or the same ambiguity error.

### F13 — A recovery from a grower can be turned into a payable invoice — P1

GL 268 sums `Abs(GrowerPaymentForPool(...))`; GL 320 again makes each payment line positive. GROUP 278–290 can correctly produce a positive ledger payment when a downward adjustment means the grower has already been paid too much. Taking the absolute value removes that distinction.

Example: prior payments are $800 and the revised entitlement is $600. The close's recovery is $200, but the document builder treats its magnitude as a positive settlement and can create a further $200 purchase invoice instead of a recovery credit memo, assuming no other charges change the net document sign.

Suggested correction: preserve signed grower entitlement through settlement aggregation and document line construction; choose invoice versus credit memo from the signed net. Future validation: negative entitlement, mixed positive/negative pools and a net-zero settlement.

### F14 — Grower value charges use the wrong sign, accumulated payments and the first template — P1

GROUP 335–346 picks the first active GroupClose template for a transaction type, bypassing normal eligibility and precedence. It multiplies the rate by `GetGrowerPaymentInPool`, which sums all PP/PPV payments for that grower/pool, without filtering the current payment ID (521–528). Normal payment ledger amounts are negative, but Grower Charge amounts are documented and consumed as positive costs (420; GL 273, 343).

Example: a payment ledger of -$400 and a rate of 0.02 yields a -$8 grower charge; subtracting that charge adds $8 to the settlement. A later close also bases the new fee on accumulated payments rather than just the current run. Per-grower template filters are ignored by the first-row lookup.

Suggested correction: use the shared matching engine with a complete grower context, a defined positive fee base, and explicit incremental-versus-cumulative accounting. Future validation: two provisional closes, a final close, and different configured rates for two growers.

### F15 — Direct consignment G/L posting discards reversal signs — P1

CONS 205 always sets `AmountToPost := Abs(PoolLedgerEntry.Amount)`, then uses the same G/L and balancing accounts. Equal-and-opposite pool amounts of +$100 and -$100 therefore both produce the same G/L direction through this function; they cannot cancel each other.

This matters when restoring credit reversals, and for other negative revenue or positive charge reversals. F01 currently masks part of the credit case by passing zero. Suggested correction: define signed posting per transaction type and use the inverse posting for its reversal. Future validation: a revenue/credit pair and a charge/reversal pair net to zero in both pool and G/L records. This is a sign-consistency finding, not a judgement about the client's account selection.

### F16 — Pool and Pool Group close workflows — deferred business-rule review

**Status updated 20 September 2026:** Ben asked to return to this section later because the workflow difference may be intentional. The difference between the two close/payment policies is not a confirmed bug, and consolidation is excluded from the current fix scope. Preserve the existing workflows and payment rules. The source observations below remain evidence for a future review; they do not authorise changing close behaviour.

Both routes are exposed: `_TAC Pool_.Page.al` 81/96 calls POOL; `_TAC Pool Group Card_.Page.al` 159 calls GROUP. The individual-pool route increments Pool Provisional Count/Close Sequence (POOL 22–25), but its sequence validators read **Pool Group** Provisional Close Count (418–420, 569–571). It never increments that group count. After one pool-level provisional close, the next pool action requests sequence 2 while the validator can still expect 1.

There are additional financial integration gaps in the same route: POOL writes payment ledger/G/L without creating the group Payment Header or grower purchase documents, and its direct G/L writers (193–232, 494–535) do not mark the ledger Posted to G/L. A later group close can select those already-posted entries again at GL 63–75.

Deferred follow-up: first establish the supported workflows and intended payment rules. Then assess the counter and posting-state observations within that design. No consolidation or close-policy change is selected. If this section is reopened, validation should cover successive pool closes, group closes, and whether mixing the two actions is supported without duplicate G/L posting.

### F17 — Final pool close does not clear interim revenue — P1

The pool provisional route reverses the previous interim balance and posts a new estimate (POOL 17, 20). The final route (27–41) does not call `RevertInterimRevenue`. No other final-close reversal of this interim balance is present in the imported engine.

Where a prior provisional generated a nonzero interim balance, the final route can leave that balance in G/L even after realised revenue has been posted. An external extension could supply another reversal, but that has not been verified here.

Suggested correction: explicitly clear the outstanding estimate during finalisation and tie the reversal to the original estimate's dimensions/source. Future validation: provisional while uninvoiced, then invoice and final close, with no outstanding interim balance.

### F18 — G/L completion flags can cover entries that were never posted — P1

GL 139–143 skips a generated journal line with no account. GL 78–88 subsequently marks **all** unposted non-movement entries in the group as posted. Optional transaction types are not protected by the mandatory-account check, so a nonzero optional entry with a blank account can disappear from the future posting queue.

The resume path also calls that group-wide marker (GL 37). If new entries arrive after the interrupted run, it can mark those as posted using evidence of the earlier run's batch, without posting them.

Suggested correction: persist the exact ledger entries included in each payment/posting run, mark only those successfully posted, and error or retain a visible pending state for unmapped nonzero entries. Future validation: optional unmapped charge and a new entry inserted between interruption and resume.

### F19 — The second provisional payment cannot use the intended resume path — P1

GROUP allows two provisional closes for Internal growers (92–94), but `ResumeLastClose` rejects any incomplete provisional payment when the group is already Provisionally Closed (65). That is also the normal group status while a second provisional run is in progress.

If the second run persists its G/L stage and then fails during purchase posting, the intended recovery action rejects it. Suggested correction: determine whether the particular payment run already advanced the group, using run identity/completion state rather than group status alone. Future validation: interrupt the second provisional after G/L, resume once, and verify there is no duplicate document or counter increment.

### F20 — The open-group check is applied to the wrong record — P1

`_TAC Pool Group Header_.Table.al` 95–101 loads a match into its local `PoolGroup` variable but calls unqualified `TestStatusOpen()`. That checks the procedure's receiver record, not the record just found. Several callers invoke FindOrCreate on a fresh record variable whose default status is Open.

Consequently finding a Closed group can pass the intended status check and allow further source postings into that group. Suggested correction: validate the retrieved group explicitly and decide the permitted treatment of late invoices/credits after provisional/final close. Future validation: a fresh caller resolving a closed group, with no additional ledger writes.

### F21 — Reconciliation and preview no longer use the same identity rules as posting — P2

This expands the earlier local assessment. RECON 577–618 no longer populates PoolWeek or Season, while its scanning callers still filter groups using those outputs (73–75, 126–128, 180–182, 226–228). Valid production/invoice/consignment/credit sources can therefore be skipped for normal nonblank weeks. These scans also locate a pool by group/variety/grade/size without grower.

PREVIEW still reads season/week from line dimensions (99–104), whereas posting derives week from the batch plan date. Its PoolPrototype omits the grower, and its existing-pool lookup also omits grower (143–161). The preview can therefore describe a different target or issue a block that does not match posting.

Suggested correction: share one read-only source-resolution/allocation contract across posting, preview and reconciliation. Future validation: sources without obsolete week dimensions, two growers sharing variety/grade/size, and a deliberately missing ledger entry that reconciliation must identify.

### F22 — Adjustments and expenses can mix a pool with the wrong group — P1

The adjustment and expense tables allow selection from all pools, without restricting them to the selected group. Their posting code validates only the header group, then writes that group ID alongside the independently selected pool code: `_TAC Pool Adjustment Post_.Codeunit.al` 14–22, 46–50; `_TAC Pool Expense Post_.Codeunit.al` 14–20, 45–48.

An open group A can therefore be selected with a pool belonging to closed group B. The result has inconsistent ownership: pool-based sums affect B, group-based sums affect A, and the closed group's intended protection is bypassed.

Suggested correction: resolve and validate the actual pools and their groups at posting; enforce the authorised transfer rules, grower ownership and same/different-group treatment explicitly. Future validation: correct-group entry, wrong-group pool, closed destination and mismatched grower. Also protect posted source records from later edits that would make reconciliation reconstruct different values.

### F23 — Pool reports link the wrong fields and mislabel transaction type — P2

`_TAC Pool Return_.Report.al` links Pool **Season Code** to header **Pool Group Code**; `_TAC Open Pool Balance_.Report.al` links Pool **Season Code** to header **Pool Group ID**. These are not the Pool Group ID relationship. For example, season 2026 does not equal group code PG-2026-W08-I, so the report can omit its pools despite existing data.

`_TAC Pool Group Summary_.Report.al` also exposes Entry Type under the column named TransTypeCode, losing distinctions such as PR, FR and specific charge codes.

Suggested correction: join pools to groups using Pool Group ID and expose the actual transaction type code. Future validation: a known group with multiple pools and several transaction types appears completely in the exported report dataset. Report layout, statement/payment filtering and tax-invoice readiness need separate acceptance; they are not certified by this source review.

### F24 — The unpriced-consignment check reads an uncalculated FlowField — P2

POOL 547–550 gets a fresh Consignment record and immediately reads Fruit Payment Exists. That field is a FlowField (`_TAC Consignment Header_.Table.al` 154–159), but this path does not calculate it or enable automatic calculation. With Allow Prov. with Unpriced KG disabled, the close can reject a consignment even when a fruit-payment record exists.

Microsoft documents that FlowFields are runtime calculations and need calculation in code when not otherwise automatically calculated. See [FlowFields overview](https://learn.microsoft.com/nl-nl/dynamics365/business-central/dev-itpro/developer/devenv-flowfields).

Calculating the field is necessary but not sufficient for the intended per-line check: the field only asks whether **any** fruit payment exists for the whole consignment. Suggested correction: check the relevant line/allocation's priced quantity and state. Future validation: fully priced consignment, one priced line with another unpriced, and the explicit setup override.

## Additional matters requiring validation or a business decision

These are deliberately separate from the source defects above. Their final impact depends on the accepted scope, configuration, standard posting behaviour or other installed extensions.

- **GST and reporting dimensions:** pool charge GST is calculated, but grower-charge creation does not populate GST Amount and purchase lines use the clearing account without explicitly selecting transaction-specific VAT treatment. G/L journal creation also leaves season/week dimension stamping as a TODO. Compare actual posting setup and resulting documents with the required treatment; this review does not infer the correct tax treatment or claim a quantified tax error.
- **Close completeness:** the group route leaves unfinished-production/despatch checks as TODOs and can proceed without distributing a nonzero value if adjusted kilograms are zero. Agree the required blockers and late-entry policy before accepting a final-close workflow.
- **Interruption/concurrency:** there is no explicit group-close locking or unique group/payment-number key in this code; payment numbers are Count + 1. Standard posting commits and simultaneous runs need controlled validation. Absence of LockTable alone is not proof of a reproduced race.
- **Partial shipments and consignment lifecycle:** ProcessPostedShipment always calls Release then Despatch, whereas Release requires Open. Confirm whether a second shipment should reuse the existing consignment or use a fresh one. Also confirm whether zero-freight collections are supported; current allocation rejects zero total freight.
- **Currency and reconciliation completeness:** invoice posting converts revenue to LCY, while the reconciliation expectation uses SalesInvoiceLine.Amount. The scanner currently cannot reliably reach those records because of F21; once corrected, currency-aware comparison and explicit amount/quantity mismatch statuses need attention. Current Found status establishes existence, not that every amount is correct.

## Items not being presented as engine bugs

- The earlier deliberately missing SIZE value was an expected negative test/data issue. Rejecting a missing required dimension is not itself an engine defect.
- The last recorded evidence showed the requested vendors and numeric grower dimensions correctly linked. This report does not recommend renumbering them to hide the lookup bug.
- The requested one-plan-per-grower/block/day correction is separate from these posting defects. No plans were split during this review.
- Source-only scenarios have not been called reproduced sandbox failures. The earlier actual grower error and pool-code collision remain documented separately.

## Suggested team sequence

First correct source identity, shipment/invoice allocation, unit conversion and signed credit/settlement handling together. Then unify close state, recovery and G/L completion tracking. Update preview, reconciliation and reports to use the same source resolution so the team can verify results accurately. Validate the documented scenarios in an agreed test run before relying on payment output. No fixes or test run have been authorised or performed as part of this review.

## Shareable findings table

All F-items below are source-confirmed findings with conditional runtime impact, not newly executed BC tests. K-items refer to the previous observed problems.

| ID | Priority | Finding | Potential effect | Suggested change |
|---|---|---|---|---|
| K1 | P1 | Vendor account used as grower dimension | Production finish fails for GRW-030 / 030 | Separate vendor identity from dimension value throughout posting |
| K2 | P1 | Pool code omits grade/size used by lookup | Different logical pools collide | Allocate a unique stable ID matching the full business identity |
| F01 | P1 | Credit amount/context left uninitialised | Credit can leave pool revenue unchanged | Restore signed, allocated credit reversal and completion checks |
| F02 | P1 | Shipment line matching omits grower/pool | Mixed-grower fruit attributed to first grower | Preserve separate ownership allocations |
| F03 | P1 | Shipment counts full original output | Partial pallets overstated or counted again | Use actual shipped/application quantities |
| F04 | P1 | Wrong shipment line/type stored | Revenue and evidence miss or misidentify sources | Store current source line and actual source type |
| F05 | P1 | Invoice total reused per shipment line | Pool revenue can exceed the invoice | Allocate once globally and reconcile exact totals |
| F06 | P1 | Unresolved/first-line invoice attribution accepted | Missing revenue or charges assigned to wrong pool | Require complete allocation before completion |
| F07 | P1 | Standard KG conversion factor multiplied | Wrong kilograms and quantity-based charges | Convert source to base, then base to target correctly |
| F08 | P1 | Freight/revenue kg added to contribution kg | Inflated charge bases and distorted shares | Use defined signed movement types for contribution totals |
| F09 | P1 | Customer rates fall through to zero; ship-to omitted | Rebates/ripening missed or blocked | Complete rate resolution and posted ship-to context |
| F10 | P1 | Dispatch charges run with empty context | Misleading failure or unassigned charge rows | Align the charge trigger and populated context |
| F11 | P1 | Destination rules checked against blank grower | Valid despatch blocked; actual growers not checked | Validate each actual grower against applicable legs |
| F12 | P2 | Later template clears an existing tie | Ambiguous rate silently accepted | Preserve ambiguity until a superior match replaces it |
| F13 | P1 | Settlement uses absolute payment amounts | Grower recovery can become another payment | Preserve sign through invoice/credit construction |
| F14 | P1 | Grower fees use negative cumulative payment and first template | Fee adds money or repeats prior bases | Use matched template and correct current-run signed base |
| F15 | P1 | Direct G/L posting takes absolute value | Reversal posts in original direction | Use transaction-specific signed posting |
| F16 | P1 | Pool/group close state diverges | Next close blocked; mixed routes can repost G/L | Use consistent close state and posting-run tracking |
| F17 | P1 | Final close omits interim reversal | Estimate can remain after finalisation | Clear outstanding interim balance at final close |
| F18 | P1 | Group-wide Posted flags exceed posted set | Unposted entries can be hidden | Track and mark exact posted entries only |
| F19 | P1 | Resume rejects a second provisional run | Interrupted payment cannot use recovery action | Resume by payment-run completion, not group status alone |
| F20 | P1 | Open-status check uses wrong record | Further postings can enter a closed group | Check the retrieved group explicitly |
| F21 | P2 | Reconciliation/preview resolution differs from posting | Missing sources or wrong target preview | Share source resolution and include grower identity |
| F22 | P1 | Adjustment/expense pool and group can disagree | Wrong group affected; close protection bypassed | Validate actual pool/group/grower relationships |
| F23 | P2 | Report joins and transaction-type column incorrect | Empty/inaccurate pool reports | Correct joins and exported transaction code |
| F24 | P2 | Unpriced check uses uncalculated, header-level field | Incorrect provisional-close block or incomplete check | Check calculated line/allocation pricing state |
