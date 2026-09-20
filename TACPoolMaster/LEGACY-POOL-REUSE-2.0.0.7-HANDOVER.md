# Temporary legacy Pool Code reuse — 2.0.0.7

Status: **published successfully to Pool_Sandbox on 20 September 2026. Four named focused checks passed in LIVE APMS; no failures.**

Target: Pool_Sandbox, tenant d000c867-fb80-4af4-9cc1-3655530c967e. Josh's test company is LIVE APMS. The extension is installed environment-wide.

## Request and behaviour

Ben asked to restore the previous code-reuse behaviour temporarily and let the team test its impact. This is a compatibility trial, not a completed fix to the pooling business model.

The exact-match lookup remains Group + Variety + Grade + Size + Grower. If it finds a pool, that code is reused as before. Otherwise the original identifier generator runs. When that code already exists, its existing pool is returned instead of inserting a duplicate primary key. The existing pool's SystemId, grade, size, description and other fields are retained; existing ledger entries and references are untouched. A separate record variable performs the primary-key lookup so the initial grade/size filters and new record values cannot obscure or overwrite the existing pool.

Only Table 50208's FindOrCreate method and its comment change; 129 other AL objects match published 2.0.0.3. The package version changes to 2.0.0.7. No field/key/schema change, migration, sequence, grower mapping, quantities, charge routine or close/payment routine change is included. The published grower-dimension correction remains present.

## What the team is testing

- Repeated batches for the same grower/week/variety/grade/size continue contributing to an existing pool.
- A different grade or size that generates the same code will now also reuse that pool. Its header retains the first grade and size. This is deliberate historical compatibility for the requested trial.
- Settlement aggregates by Pool Code, so reused classifications share that code's totals. Close-time rules using the pool header may see only its original classification. This release does not certify that outcome as financially correct.
- Different growers remain separated by the existing identifier. This does not implement the scope's shared Variety + Grade + Size pool across growers.
- No new concurrency handling is introduced. This fallback alone is not a concurrency-safe redesign.

## Verification

Engine release, forward recovery and helper 1.0.0.4 compile successfully. All 130 starting AL files were compared with the published 2.0.0.3 package; candidate differs in exactly one AL file. Recovery matches all 130 baseline AL sources. Engine 2.0.0.7 and helper 1.0.0.4 were published successfully using explicit tenant/environment arguments and normal Synchronize, without forced upgrade or dependency publication.

The helper uses RequiredTestIsolation = Function. Checks cover repeated identity reuse, changed grade/size reuse while preserving the original pool, and unchanged separation between growers/weeks. A separate read-only check verifies fixture records are absent. No Josh production order is finished, no pool is closed, no invoice/payment is posted, and no financial end-to-end test is included.

Native results: `RepeatedBatchIdentityReusesPool`, `LegacyCollisionReusesWithoutOverwrite`, and `DifferentGrowerAndWeekRemainSeparate` all passed. A subsequent separate run of `LegacyCheckFixturesAreAbsent` passed, confirming no fixture pools, pool groups or weeks remained. The runner reports four and two passes respectively because each run also includes a blank-name aggregate result; there are four named checks in total. The broader existing-data preflight and six grower checks were not rerun for this release.

Evidence: `build/legacy-reuse-publish-result.log`; `../PoolGrowerFixTests/publish-result-1.0.0.4.log`; `../PoolGrowerFixTests/legacy-reuse-results-1.0.0.4.log`; `../PoolGrowerFixTests/legacy-reuse-fixture-absence-1.0.0.4.log`. Team functional testing of actual production finishes and financial outcomes remains outstanding. Refresh the BC session before retrying.

## Packages and recovery

- Release: `build/DIY-ERP_TAC Pool Master_2.0.0.7_legacy-reuse.app`
- SHA256: `8e467870c7f54e68a2d84a19c3e80a991d8cfd9cd6d307cbd5584cb518a4a780`
- Recovery: `build/DIY-ERP_TAC Pool Master_2.0.0.8_legacy-reuse-recovery.app`
- Recovery SHA256: `fca80d0ac4a126e4102f3800dc0c55c9a7c7d7553c5af1a54416fa7b80977a3b`
- Source snapshot: `D:/WOLFETAC/.snapshots/PoolMaster-legacy-reuse-20260920/recovery-source-2.0.0.8`.
- Diff and verification: `build/legacy-reuse-2.0.0.7.patch`, `build/legacy-reuse-package-verification.json`.

To remove this trial, publish the compiled 2.0.0.8 recovery to the same tenant and Pool_Sandbox using normal Synchronize. This restores 2.0.0.3 behaviour through a higher version and retains the grower fix. It will restore the duplicate-code error for mismatched grade/size. Recovery is compiled/source-verified but not deployed or rehearsed. It does not unmerge, reverse, remove or redistribute transactions posted while 2.0.0.7 is installed. Data recovery would be a separate task.

Do not use held 2.0.0.5/2.0.0.6 packages for this trial. Broader changes and both close workflows remain deferred.
