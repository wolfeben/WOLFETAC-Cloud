# Grower identity fix — TAC Pool Master 2.0.0.3

Target: Pool_Sandbox, company LIVE APMS, tenant d000c867-fb80-4af4-9cc1-3655530c967e.

Status: **published successfully to Pool_Sandbox on 20 September 2026; six focused checks passed in LIVE APMS.** Pool Master version is 2.0.0.3. Josh can refresh Business Central and retry the production finish. This is a focused fix, not completion of the wider engine review.

## What changes

Finishing a packing production order previously treated its vendor account (for example `GRW-030`) as the grower dimension value. The vendor card correctly carries `GROWER CODE = 030`, so the reverse vendor lookup failed.

Production posting now reads the existing vendor's configured default grower dimension and passes that value to the pool ledger and production charge context. Vendor fields and pool ownership continue to use the vendor account. The production diagnostic uses the same mapping. The helper checks that the mapping is unique and that any source grower dimension agrees with the vendor. It preserves leading zeros and makes no assumptions about vendor-number prefixes.

Only three codeunits differ from the verified installed 2.0.0.2 package: 50271, 50276 and 50280. The other 127 AL objects match. There are no table/schema changes, data migrations, payment/close changes, quantity conversion changes or pool identifier changes.

This addresses the reported **production grower-code error**, not every identity issue in all engine paths. Consignment/invoice identity handling, pool-close charge identity, reconciliation and the separate pool-code collision remain outside this focused release. A successful grower lookup does not establish that an entire production finish or pool close will succeed.

## Packages and preservation

- Release: `build/DIY-ERP_TAC Pool Master_2.0.0.3_grower-fix.app`
- SHA256: `fcbe5f62edfe9eb236f4509e9fa449f09686fc07ea463e10f4fb3163ac0c4a34`
- Recovery: `build/DIY-ERP_TAC Pool Master_2.0.0.4_recovery.app`
- Recovery SHA256: `e6da2efeb4ae9e67ab4bdcd574bd83bfe08d08062c32b9433c7e7b22ca0c8542`
- Recovery source matches the verified installed 2.0.0.2 AL source. It uses a higher version to restore the previous behaviour through a normal upgrade. It is compiled and source-verified, but has not been deployed as a rollback rehearsal. Publishing it would not undo records users have posted in the meantime, and would restore the original grower bug.
- Full broader WIP is preserved outside active compilation in `D:/WOLFETAC/.snapshots/PoolMaster-grower-only-20260920/deferred-full-work-in-progress.zip`. Three WIP-only AL files are also preserved in that directory. Do not restore them into this release or rerun the broad modification scripts.
- Baseline provenance: `SOURCE-PROVENANCE-20260920.json`. Detailed candidate diff and binary/source checks: `build/grower-only-2.0.0.3.patch` and `build/grower-only-package-verification.json`.

## Focused verification

Both release and recovery compiled successfully (130 AL objects each). The independent `Pool Grower Identity Tests` app compiled with six checks and `RequiredTestIsolation = Function` so temporary test data is rolled back.

Checks cover the five existing vendor mappings; order 1221 and its nine source-line dimensions; arbitrary vendor numbering and leading zeros; missing vendor dimensions; ambiguous vendor mappings; and conflicting source dimensions. They do not finish Josh's production orders, close pools or post financial documents.

Native checks completed successfully against installed 2.0.0.3 in LIVE APMS. The runner reports seven passes because it includes a blank-name aggregate entry in addition to the six named checks. All six named checks passed, with zero failures. The production-line check also validated the required pool dimensions on all nine current lines of order 1221.

The first test run exposed an existing limitation in the separate header diagnostic: order 1221 has no pool-type value on its header dimension set. The finishing routine uses production-line dimensions. The corrected test therefore verifies all nine actual line dimension sets, then checks the header resolver with valid line dimensions assigned to the record variable in memory only. It does not alter the order or claim that the original header diagnostic is now valid. Expected-error tests clear their last-error state to avoid an erroneous aggregate failure in the runner. No further engine changes were made after the initial 2.0.0.3 publication.

Evidence: `build/grower-only-publish-result.log`; `D:/WOLFETAC/Cloud/PoolGrowerFixTests/publish-result-1.0.0.1.log`; `D:/WOLFETAC/Cloud/PoolGrowerFixTests/test-results-1.0.0.1.log`. The initial results remain in `test-results.log` for transparency. The test helper app (version 1.0.0.1, CU59980) has no subscribers or normal business actions.

No end-to-end finish, pool close or grower payment was executed. Other known engine issues, including pool identifier collisions, can still block later steps and must not be confused with a recurrence of the resolved vendor/dimension mismatch.
