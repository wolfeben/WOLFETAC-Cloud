# TAC Stock & Logistics (SAL)

This is the canonical Cloud Business Central project for TAC Stock & Logistics.

- Project root: `D:\WOLFETAC\Cloud\SAL`
- App ID: `1802aae7-3e0b-4d5d-89c2-0ec78ca9032f`
- Publisher: `WOLFE`
- Object range: `58000-58499`
- Test project: `D:\WOLFETAC\Cloud\Test\SAL`

Primary user pages:

- Page 58006 — Packing & Logistics Monitor (read-only operational journey with Queue and Calendar views)
- Page 58007 — Stock & Logistics Planner (transactional planning)

Planner fill workflow (app version 1.1.0.0):

- Draft demand can remain exact, become a fill group, or split into an exact plus fill balance.
- Only the unplanned exact balance can be converted; existing exact pallet allocation is protected.
- Fill groups have unlimited eligible SKUs, exact marketer matching, optional per-order minimums and maximums, pallet-equivalent caps, and an explicit mixed-pallet rule.
- A fill balance can be reduced or returned to exact while it is still unallocated. Every conversion and adjustment requires a reason and creates an audit event.
- These quantities are planned composition. They are not scanner-confirmed packed quantities and do not alter or post the source Sales Order or Transfer Order.

Freight and arrival dates now appear inside page 58006 through its Calendar toggle. Page 58016 is retained only as a non-searchable compatibility/detail projection, not as a separate primary workspace. On-premises Packing Wall, operator, scanner, Unconsigned and physical completion remain outside this Cloud app until the versioned facility integration is implemented.

Page 58012 is the graphical Fill Group Layouts workspace. SAL administrators can start from Premium supermarket, Class 1 mix, Export 28/30 or blank layouts; filter live BC inventory items by product type and size; set per-SKU quantity or pallet caps; and save the selection as a reusable marketer-specific fill group.

Movement source lines (app version 1.1.0.2):

- Calendar cards include a compact preview of the underlying BC item/size lines.
- Selecting a movement in Queue & Details shows every projected source line with item, variant, description, quantity and the original BC unit of measure.
- Transfer lines distinguish outstanding quantity from quantity already in transit.
- Units are not silently converted. In particular, `TE` remains `TE` unless a verified item unit-of-measure conversion is introduced separately.

Transcript follow-ups intentionally outside the 1.1.0.0 fill slice are: scanner-backed completion and reclassification of already released work, 80-percent/amber near-full status, freight-leg gating for pallet-pool movements and invoice matching, EDI item-mapping exceptions, and setup-change history.

Compile and publish from this folder only. Never publish the preserved `D:\WOLFETAC\Cloud\App` copy or an old combined `WOLFETAC Cloud` package.
