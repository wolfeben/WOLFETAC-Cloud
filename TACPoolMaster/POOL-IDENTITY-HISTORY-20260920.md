# Pool-code collision: history and grouping decision

20 September 2026. Review requested by Ben after the duplicate-code error for `2026-13-I-HA-GRW-100` in Pool_Sandbox / LIVE APMS.

**Status: identifier change held, not published.** Installed Pool Master remains 2.0.0.3 with the grower-code fix only. The local engine source has also been restored to that released version. Candidate 2.0.0.5 and recovery 2.0.0.6 were compiled but neither was published. The proposal is preserved at `D:/WOLFETAC/.snapshots/PoolMaster-identity-20260920/held-identity-proposal-2.0.0.5.zip`.

## What changed

All inspected versions first look for a pool matching group, variety, grade, size and grower vendor. The generated code includes season, week, type, variety and grower, but omits grade and size.

| Archived source | Behaviour after the full identity lookup finds no match |
|---|---|
| 2.0.0.1 export, 11 September | Generates the shorter code, checks whether that code already exists, and inserts only if absent. Returns the code either way. |
| Earlier 2.0.0.2 export, 17 September | Same fallback as above. |
| Later 2.0.0.2 exports, 17–20 September | The fallback check is commented out. Always attempts to insert the newly requested pool, so two identities generating the same code collide. |
| Grower-fix release 2.0.0.3 | Pool table matches the verified installed 2.0.0.2 source. The grower fix did not introduce this change. |

The older key lines were:

```al
"Pool Code" := GetPoolCode();
if not Pool.Get("Pool Code") then Insert(true);
exit("Pool Code");
```

The later code uses the local Pool record throughout and contains:

```al
Pool."Pool Code" := Pool.GetPoolCode();
//if not Pool.Get("Pool Code") then
Pool.Insert(true);
exit(Pool."Pool Code");
```

This establishes the technical cause. It does not establish who removed the fallback or why. The exported versions are not a developer change log; archive timestamps are evidence of the copies inspected, not proof of deployment time. Different source contents share the same 2.0.0.2 version label.

## Multiple postings versus multiple pool identities

Many ledger transactions sharing one Pool Code is normal. Both versions reuse a pool when the full identity matches. There is no need to allocate a new pool for every production order, pallet, serial or ledger entry.

The older fallback also reused an existing code when the full identity did **not** match. For example, a new size-23 request could return the code of the existing size-25 pool. That does not update the stored pool's grade or size; it sends subsequent postings to the existing reference.

This may explain why older versions appeared to accept more items. It is not enough to conclude that all those items were assigned to the intended financial pool. Some different items legitimately share the same classification; others differ in grade or size. Historical records need to be distinguished on that basis.

## Is a sequence or new identifier safer?

It depends on the intended financial grouping. A new identifier per **genuine pool** can preserve distinct pools; a new identifier per **transaction** would fragment an otherwise shared pool and is not the proposed approach. Simply restoring the old fallback would suppress the error but could combine classifications the full lookup says should be separate.

The June RFS describes pools by variety, grade and size within a week/type group. If that is still the approved rule, the fallback conflicts with it. If the rule was changed to combine those classifications, the lookup, header fields and calculations need to reflect that consistently. Available scope is insufficient to settle a later policy change.

The code uses Pool Code in ledger and payment lookups, charge allocation, consignment references, adjustments, expenses, reports and G/L document references. In particular, group-close charge context takes grade and size from the pool header, while value and quantity helpers aggregate by Pool Code. Changing grouping can therefore change charges or settlement totals even when every reference remains valid.

The inspected local engine, Pool Review and TACDIRECT sources did not reveal a consumer parsing the current code into season/week/grower fields; this is not a guarantee about external reports, spreadsheets, integrations or operator practices. Existing references must not be renumbered as part of this investigation.

**Recommendation:** hold the new-code/sequence proposal; confirm whether grade and size define separate financial pools; then align both lookup and code allocation with that one rule. Preserve many transactions per pool and preserve existing references. Do not reinstate the fallback merely to bypass the error.

## Evidence and preparation performed

- [Earlier 2.0.0.1 source](<C:/Users/BenL/OneDrive - IXODIGITAL PTY LTD/Client Files/AVOS/outputs/pooling-scope-review-20260911/installed-source-2.0.0.1/_TAC Pool_.Table.al:159>) shows the fallback.
- Earlier 2.0.0.2 archive: `C:/Users/BenL/Downloads/TAC Pool Master_DIY-ERP_2.0.0.2.zip`, SHA256 `3b6752d6c7c924eae255d55e800364f2102ae48b970301af8af60012d560fcff`.
- Later 2.0.0.2 archive: `C:/Users/BenL/Downloads/TAC Pool Master_DIY-ERP_2.0.0.2 (1).zip`, SHA256 `b3fc5e9e64b345242b9a82c9698caf2ca65e652ebd444193d04677a086be3307`.
- Verified installed baseline provenance is in `SOURCE-PROVENANCE-20260920.json`; release 2.0.0.3 is recorded by commit `8fc60a6`.
- All-company read-only preflight found no duplicate **complete** business keys at the time checked. That is consistent with the reported failure: distinct full identities are colliding on the shorter code. It does not approve the choice of business key.
- Test helper 1.0.0.2 was published for that read-only preflight; evidence is `D:/WOLFETAC/Cloud/PoolGrowerFixTests/pool-identity-preflight.log`. The proposed identity/production-posting tests were compiled locally but were not published or executed. No production status, stock, pool, charge or payment data was changed by this review.
