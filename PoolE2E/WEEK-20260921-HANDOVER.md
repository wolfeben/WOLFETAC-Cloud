# September pooling dataset — handover

20 September update: the user clarified that plans must be per grower/block/day, then questioned whether grouping caused the error. A correction helper is installed but **no plans have been split**. Live assessment confirms all 50 production/receipt vendor links and all 450 numeric grower dimensions are correct. The current error on order 1221 is traced to the installed engine assigning vendor GRW-030 to a variable consumed as grower dimension 030. See [plan assessment](WEEK-20260921-PLAN-ASSESSMENT.md). No engine fix has been applied.

Environment: Pool_Sandbox. Company: LIVE APMS. Season 2026 / pool week WK-2026-13, 21–27 September. Deliveries and daily plans cover 21–25 September 2026.

All requested receipts, consumption and output are recorded, and production source dimensions are now complete. Normal production-order finishing is blocked by a duplicate pool code in the installed engine. No functional pooling scenarios, pool closes, payments, reversals or sales were run.

| Created data | Actual |
|---|---:|
| Bin deliveries / posted receipts | 50 |
| Bins received and consumed | 500 / 500 |
| Daily batch plans | 5 |
| Production orders / output lines | 50 / 450 |
| Regular pallets | 900 |
| Mixed pallets, each containing all 50 orders | 9 |
| Unique pallet IDs and matching output lot IDs | 909 |
| Posted order/pallet contributions | 1,350 |
| Unique 24-digit serials | 106,656 |
| Output item-ledger entries | 106,956 |
| Orders Released / Finished | 50 / 0 |

All 450 production output lines have their planned quantities posted and zero remaining quantity. All 500 received bins have been consumed. Each unit-counted serial is recorded both in native pallet detail and in its own inventory output entry. Bulk output is recorded by lot/pallet without invented unit serials.

| Item | Pallets | Recorded quantity | Serials |
|---|---:|---:|---:|
| PKD-HABKBN1KPP | 101 | 44,440 kg nominal (4,534.69396 BK) | 0 |
| PKD-HABKGL1KPR | 101 | 9,696 units | 9,696 |
| PKD-HAKGMXPG | 101 | 44,440 kg | 0 |
| PKD-HATYAV20C1 | 101 | 16,160 units | 16,160 |
| PKD-HATYAV23C1 | 101 | 16,160 units | 16,160 |
| PKD-HATYAV25C1 | 101 | 16,160 units | 16,160 |
| PKD-HATYGL20PR | 101 | 16,160 units | 16,160 |
| PKD-HATYGL23PR | 101 | 16,160 units | 16,160 |
| PKD-HATYGL25PR | 101 | 16,160 units | 16,160 |

Each item has 100 regular pallets plus one mixed pallet. Each mixed pallet has all 50 orders represented. Regular pallets post on their delivery day; mixed contributions post on 25 September. Output expiry is 21 October 2026.

PKD-HABKBN1KPP uses the existing 9.8 kg/BK conversion. Five-decimal base quantity precision gives 440.000008 kg per nominal 440 kg pallet, or 44,440.000808 kg across 101 pallets. Item/UOM setup was not changed.

## Production completion pending

The normal finish request for order 1207 stopped because GROWER TYPE was absent from its production source line. The data-preparation helper omitted that inherited attribute. Its completion action uses the original receipt and requires agreement with current grower defaults; it does not rewrite posted inventory.

On 19 September the user approved I (Internal) for the missing grower type. Helper 0.1.0.17 was installed and its grower-only action applied I to all 450 production source lines across the 50 orders, requiring agreement with each original receipt, current vendor default dimension and vendor Grower Pool Type. The downloaded source snapshot confirms 450 Internal lines and no errors. Packing values, quantities and posted inventory dimensions were not changed.

The user's final packing instruction for PKD-HAKGMXPG is PACK TYPE=BK and PACK CAT=KG. Helper 0.1.0.19 filled BK on its 50 production source lines while retaining KG. All 450 lines now have grower type I and nonblank packing type/category. Quantities, other source classifications, item defaults and posted inventory dimensions were preserved. The earlier BK/BKBN action in 0.1.0.18 was never run; the category was never changed to BKBN.

The requested normal finishing stage was resumed after the dimensions were saved. It stopped on the first production order, 1207, with: "The record in table Pool already exists. Identification fields and values: Pool Code='2026-13-I-HA-GRW-100'." The call stack identifies TAC Pool.FindOrCreate in TAC Pool Master 2.0.0.2. This is the previously identified pool identity collision, now encountered with the requested September dataset. No retry, finish bypass or pooling-engine correction was made. All 50 orders remain Released; successful pooling has not been established.

Posted output retains its original dimensions, so its historical GROWER TYPE and packing type can still appear blank; the corrections are on the production source used by the engine. The helper is TAC Pool E2E Test Data 0.1.0.19; the installed pooling engine remains TAC Pool Master 2.0.0.2. Packing readback: build/week-20260921-packing-applied.json. Latest status/error evidence: build/week-20260921-finish-pool-collision.json, read at 2026-09-19T03:25:05.308Z. Output totals remain 1,350 contributions, 106,656 serials and 106,956 output entries.

## Packing reference in Pool_Sandbox / LIVE APMS

PACK TYPE values are BK (Bulk), TE DOM (Domestic Tray), TE EXPORT (Export Tray), and ZE2E (TEST ONLY - ZE2E), all unblocked. The separate item PKD-HABKBNMXOI (Hass Mixed Oil Grade) has live default PACK TYPE=BK and PACK CAT=BKBN; no posted item-ledger entries were found for HABKBNMXOI in this company. That reference item's setup was not changed or copied over PKD-HAKGMXPG's user-confirmed KG category.

The live PACK CAT values inspected on 19 September are all unblocked:

| Code | Description |
|---|---|
| BIN | Bin |
| BKBN | Bulk Bin |
| BKET | Bulk |
| BKGL | Bulk General |
| BKGN | Bulk |
| KG | Kilos |
| TYAV | Tray Class 1 |
| TYET | Tray |
| TYEX | Tray Export |
| TYGL | Tray General |
| ZE2E | TEST ONLY - ZE2E |

## Find the records

Purchase orders: PO-000274–PO-000323. Posted receipts: PREC-000083–PREC-000132. Regular pallet/output-lot IDs: W26S21P0001–W26S21P0900. Mixed pallet/output-lot IDs: W26S21P0901–W26S21P0909.

| Date | Batch plan | Production orders |
|---|---|---|
| 21 Sep | BP0068 | 1207–1216 |
| 22 Sep | BP0069 | 1217–1226 |
| 23 Sep | BP0070 | 1227–1236 |
| 24 Sep | BP0071 | 1237–1246 |
| 25 Sep | BP0072 | 1247–1256 |

[Open the sandbox data page](https://businesscentral.dynamics.com/d000c867-fb80-4af4-9cc1-3655530c967e/Pool_Sandbox?company=LIVE%20APMS&page=59353&dc=0).

## Delivery-to-order map

| Date | Grower | Block | Order | Posted receipt | Delivery lot | Regular pallets |
|---|---|---|---|---|---|---|
| 21 Sept | GRW-100 | 100-A | 1207 | PREC-000083 | 1000126426 | W26S21P0001–0018 |
| 21 Sept | GRW-100 | 100-BE | 1208 | PREC-000084 | 1000226426 | W26S21P0019–0036 |
| 21 Sept | GRW-102 | 102-A | 1209 | PREC-000085 | 1020126426 | W26S21P0037–0054 |
| 21 Sept | GRW-102 | 102-B | 1210 | PREC-000086 | 1020226426 | W26S21P0055–0072 |
| 21 Sept | GRW-030 | 030-BA | 1211 | PREC-000087 | 0300126426 | W26S21P0073–0090 |
| 21 Sept | GRW-030 | 030-BB | 1212 | PREC-000088 | 0300226426 | W26S21P0091–0108 |
| 21 Sept | GRW-064 | 064-A | 1213 | PREC-000089 | 0640126426 | W26S21P0109–0126 |
| 21 Sept | GRW-064 | 064-B | 1214 | PREC-000090 | 0640226426 | W26S21P0127–0144 |
| 21 Sept | GRW-049 | 049-A1 | 1215 | PREC-000091 | 0490126426 | W26S21P0145–0162 |
| 21 Sept | GRW-049 | 049-B | 1216 | PREC-000092 | 0490226426 | W26S21P0163–0180 |
| 22 Sept | GRW-100 | 100-A | 1217 | PREC-000093 | 1000126526 | W26S21P0181–0198 |
| 22 Sept | GRW-100 | 100-BE | 1218 | PREC-000094 | 1000226526 | W26S21P0199–0216 |
| 22 Sept | GRW-102 | 102-A | 1219 | PREC-000095 | 1020126526 | W26S21P0217–0234 |
| 22 Sept | GRW-102 | 102-B | 1220 | PREC-000096 | 1020226526 | W26S21P0235–0252 |
| 22 Sept | GRW-030 | 030-BA | 1221 | PREC-000097 | 0300126526 | W26S21P0253–0270 |
| 22 Sept | GRW-030 | 030-BB | 1222 | PREC-000098 | 0300226526 | W26S21P0271–0288 |
| 22 Sept | GRW-064 | 064-A | 1223 | PREC-000099 | 0640126526 | W26S21P0289–0306 |
| 22 Sept | GRW-064 | 064-B | 1224 | PREC-000100 | 0640226526 | W26S21P0307–0324 |
| 22 Sept | GRW-049 | 049-A1 | 1225 | PREC-000101 | 0490126526 | W26S21P0325–0342 |
| 22 Sept | GRW-049 | 049-B | 1226 | PREC-000102 | 0490226526 | W26S21P0343–0360 |
| 23 Sept | GRW-100 | 100-A | 1227 | PREC-000103 | 1000126626 | W26S21P0361–0378 |
| 23 Sept | GRW-100 | 100-BE | 1228 | PREC-000104 | 1000226626 | W26S21P0379–0396 |
| 23 Sept | GRW-102 | 102-A | 1229 | PREC-000105 | 1020126626 | W26S21P0397–0414 |
| 23 Sept | GRW-102 | 102-B | 1230 | PREC-000106 | 1020226626 | W26S21P0415–0432 |
| 23 Sept | GRW-030 | 030-BA | 1231 | PREC-000107 | 0300126626 | W26S21P0433–0450 |
| 23 Sept | GRW-030 | 030-BB | 1232 | PREC-000108 | 0300226626 | W26S21P0451–0468 |
| 23 Sept | GRW-064 | 064-A | 1233 | PREC-000109 | 0640126626 | W26S21P0469–0486 |
| 23 Sept | GRW-064 | 064-B | 1234 | PREC-000110 | 0640226626 | W26S21P0487–0504 |
| 23 Sept | GRW-049 | 049-A1 | 1235 | PREC-000111 | 0490126626 | W26S21P0505–0522 |
| 23 Sept | GRW-049 | 049-B | 1236 | PREC-000112 | 0490226626 | W26S21P0523–0540 |
| 24 Sept | GRW-100 | 100-A | 1237 | PREC-000113 | 1000126726 | W26S21P0541–0558 |
| 24 Sept | GRW-100 | 100-BE | 1238 | PREC-000114 | 1000226726 | W26S21P0559–0576 |
| 24 Sept | GRW-102 | 102-A | 1239 | PREC-000115 | 1020126726 | W26S21P0577–0594 |
| 24 Sept | GRW-102 | 102-B | 1240 | PREC-000116 | 1020226726 | W26S21P0595–0612 |
| 24 Sept | GRW-030 | 030-BA | 1241 | PREC-000117 | 0300126726 | W26S21P0613–0630 |
| 24 Sept | GRW-030 | 030-BB | 1242 | PREC-000118 | 0300226726 | W26S21P0631–0648 |
| 24 Sept | GRW-064 | 064-A | 1243 | PREC-000119 | 0640126726 | W26S21P0649–0666 |
| 24 Sept | GRW-064 | 064-B | 1244 | PREC-000120 | 0640226726 | W26S21P0667–0684 |
| 24 Sept | GRW-049 | 049-A1 | 1245 | PREC-000121 | 0490126726 | W26S21P0685–0702 |
| 24 Sept | GRW-049 | 049-B | 1246 | PREC-000122 | 0490226726 | W26S21P0703–0720 |
| 25 Sept | GRW-100 | 100-A | 1247 | PREC-000123 | 1000126826 | W26S21P0721–0738 |
| 25 Sept | GRW-100 | 100-BE | 1248 | PREC-000124 | 1000226826 | W26S21P0739–0756 |
| 25 Sept | GRW-102 | 102-A | 1249 | PREC-000125 | 1020126826 | W26S21P0757–0774 |
| 25 Sept | GRW-102 | 102-B | 1250 | PREC-000126 | 1020226826 | W26S21P0775–0792 |
| 25 Sept | GRW-030 | 030-BA | 1251 | PREC-000127 | 0300126826 | W26S21P0793–0810 |
| 25 Sept | GRW-030 | 030-BB | 1252 | PREC-000128 | 0300226826 | W26S21P0811–0828 |
| 25 Sept | GRW-064 | 064-A | 1253 | PREC-000129 | 0640126826 | W26S21P0829–0846 |
| 25 Sept | GRW-064 | 064-B | 1254 | PREC-000130 | 0640226826 | W26S21P0847–0864 |
| 25 Sept | GRW-049 | 049-A1 | 1255 | PREC-000131 | 0490126826 | W26S21P0865–0882 |
| 25 Sept | GRW-049 | 049-B | 1256 | PREC-000132 | 0490226826 | W26S21P0883–0900 |

## Saved evidence

Current downloaded source record: build/week-20260921-current-handover.json. Completed-output checkpoint: build/week-20260921-output-complete.json. The files contain order/item/pallet/lot mappings, serial ranges, quantities and source-state evidence. Earlier interrupted/error checkpoints are retained separately. These local evidence files are excluded from Git; the source helper and this handover are version-controlled.

Evidence read at: 
09/18/2026 12:06:20
