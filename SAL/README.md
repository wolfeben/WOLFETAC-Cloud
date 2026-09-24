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

Pallet auto-fill (app version 1.1.0.23):

- On a Draft plan, **Fill pallets** first completes existing exact or mixed pallets from compatible remaining order lines without requiring a pallet rule. When all compatible demand is exhausted, an underfilled pallet's target is reduced to its planned quantity; an underfilled Standard becomes Custom. Existing components are preserved. It then creates additional pallets from the unallocated exact balance using active pallet rules. Fill-group balances are not automatically allocated.
- When **Allow mixed** is selected, a blank draft pallet can be composed from all compatible unallocated exact source lines, without entering every size by hand. A blank Standard changes to Mixed when it contains different products. The entered target is a maximum; if less compatible demand exists, the target is reduced to the quantity allocated. Different source orders, routes, destinations or units are not silently combined.
- Page 58011 stores active allocation rules in the original order-line unit, optionally scoped to customer, ship-to and exact item. The most specific matching rule wins. Set Woolworths WA to 152 using its actual customer and ship-to codes. No universal TE/BK/BKBN capacities are seeded because the same unit can have different item capacities; BKBN requires an exact item rule.
- Full pallets are Standard; a short remainder is Custom. The optional **Allow mixed** combines compatible short exact lines from the same order, destination, route, unit and capacity into one Mixed pallet with separate components.
- Draft pallet type/target and exact component quantity can be edited afterward. Changing a Standard component quantity converts that pallet to Custom. Standard BC validation still gates release.

Fill layouts support both a per-product pallet cap and an overall pallet-equivalent cap. For example, a supermarket layout can allow no more than five pallets of any one eligible SKU while allowing thirty pallets in total across multiple fill conversions that use the layout.

Movement source lines (app version 1.1.0.2):

- Calendar cards include a compact preview of the underlying BC item/size lines.
- Selecting a movement in Queue & Details shows every projected source line with item, variant, description, quantity and the original BC unit of measure.
- Transfer lines distinguish outstanding quantity from quantity already in transit.
- Units are not silently converted. In particular, `TE` remains `TE` unless a verified item unit-of-measure conversion is introduced separately.

Monitor pallet drill-down (app version 1.1.0.24):

- The Physical pallet plan summary on page 58006 is clickable when the selected document has planned pallets.
- Its drill-down lists the SAL planning sequence, Standard/Custom/Mixed type, target and planned quantities, component products/sizes and quantities.
- Planning sequence values such as Pallet 1 are not presented as physical barcode IDs. Until the Packing Facility integration supplies the labelled/scanned identity, the physical ID and packing status explicitly show as unavailable.

Transcript follow-ups intentionally outside the 1.1.0.0 fill slice are: scanner-backed completion and reclassification of already released work, 80-percent/amber near-full status, freight-leg gating for pallet-pool movements and invoice matching, EDI item-mapping exceptions, and setup-change history.

Compile and publish from this folder only. Never publish the preserved `D:\WOLFETAC\Cloud\App` copy or an old combined `WOLFETAC Cloud` package.
