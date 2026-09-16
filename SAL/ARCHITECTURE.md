# SAL Cloud architecture boundary

## Ownership

- Standard Cloud Business Central Sales and Transfer documents own demand and posted commercial/logistics state.
- SAL owns priority, availability for packing, pallet requirements, immutable plan versions and the combined operational view.
- The on-premises Packing Facility owns physical tray scans, pallet composition, packing progress, exceptions and Unconsigned facts.
- Standard Business Central warehouse, shipment, transfer receipt and invoicing processes own inventory and financial posting.

SAL must not turn every Sales Order or Transfer Order into Packing Facility work.

## Explicit routing

Every SAL plan source must record an execution route and facility work type. Routing must use authoritative BC fields, not customer-name text.

Execution routes:

- `MANJIMUP_PACK`
- `MANJIMUP_EXISTING_STOCK`
- `EXTERNAL_DC_FULFILMENT`
- `INTER_DC_TRANSFER`
- `NO_FACILITY_ACTION`

Facility work types:

- `PACK_NEW`
- `MATCH_EXISTING`
- `REPACK_OR_RELABEL`
- `NONE`

Only `MANJIMUP_PACK` with actionable facility work is shown on the Packing Wall. Existing stock matching may appear on the Packing Facility Operator page but must not be presented as stock to pack. External DC and inter-DC work stays in Cloud SAL and standard BC.

## Cross-environment contract

Cloud to on-premises sends a full, atomic, versioned Facility Work Package containing only facility execution data. It does not replicate pricing, credit, invoicing, DC receipt or unrelated freight administration.

On-premises to Cloud returns:

- technical receipt or rejection;
- named Accept, Hold or Query against the exact plan version;
- pallet and component progress;
- exact grouped pallet composition;
- Unconsigned composition and deterministic mismatch reason;
- allocation proposals and operation requests;
- load evidence where it belongs to the facility.

Every message must have a GUID message ID, schema version, source and target environment/company, UTC timestamp, Plan ID, Plan Version, previous version where applicable, correlation ID and payload hash. Processing must be idempotent. A Cloud plan is not marked as available at the facility until on-premises acknowledges receipt.

## BC process rules

- A Sales Order amendment or Finish Short action executes in Cloud using the controlled reopen/change/release process and creates a new SAL plan version.
- A Transfer Order remains the authority for Transfer-from, Transfer-to, shipment, In Transit and receipt state.
- Packing Complete does not mean Sales Order Shipped.
- Transfer packing complete does not mean Transfer Order complete; the applicable Transfer Receipt remains authoritative.
- Unconsigned is physical supply without an accepted allocation, not an order.
- The physical Grade Item Data marketer validates scanned stock. SAL also requires an authoritative commercial/order marketer and may not infer TAC or Costa from display names.
- Do not write Item Ledger Entry, posted shipment or posted receipt tables directly.

## Fill-group planning

- The source Sales or Transfer line remains the authoritative demand quantity and product reference.
- A Draft plan may reclassify only its unplanned exact balance to a marketer-specific fill group.
- The original exact component allocation is never silently changed. A hybrid source therefore carries an exact target and a fill target whose sum remains the source demand.
- Eligible group members and order-specific limits are snapshotted into the plan version. Later template edits cannot change released history.
- Every physical pallet component still records one exact Item, Variant, UOM and quantity. A mixed pallet is one physical pallet with multiple exact components, not an unspecified group allocation.
- Fill conversion and adjustment are Draft-only until the facility feedback contract identifies which released components are physically completed or scanned.
- Validation enforces exact and fill totals separately, marketer equality, member identity and limits, physical pallet totals, and the mixed-pallet permission.
- SAL planning does not substitute or post the source BC document line. Any commercial-document change remains a controlled standard BC process.

## Primary pages

- Page 58006: Packing & Logistics Monitor, Cloud, read-only and the primary end-to-end operational view.
- Page 58007: SAL Stock & Logistics Planner, Cloud, transactional.
- Page 58016: Freight Movement Details, Cloud, supporting and non-searchable.
- Packing Wall and Packing Facility Operator remain on-premises and are not part of this app's object range.

## First end-to-end acceptance gate

1. Publish a released Sales Order plan routed to `MANJIMUP_PACK`.
2. Confirm the exact plan version is acknowledged and appears on the on-premises Packing Wall.
3. Return pallet progress and show it in the Cloud Monitor.
4. Create an inter-DC Transfer Order plan and confirm it remains visible in Cloud but emits no facility work package.
5. Confirm Packing Complete alone does not post a Sales Shipment or Transfer Shipment/Receipt.
