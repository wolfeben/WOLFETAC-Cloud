# TAC Pool Master — local source baseline

## Focused release published — 20 September 2026

The active canonical source is now the verified installed 2.0.0.2 baseline plus only the production grower identity fix, version 2.0.0.3, published to Pool_Sandbox. Six focused identity checks passed in LIVE APMS. The broader WIP has been preserved outside the active source. Payment/close consolidation remains deferred. See [GROWER-FIX-2.0.0.3-HANDOVER.md](GROWER-FIX-2.0.0.3-HANDOVER.md) for the deployment record, package hashes, verification limits and recovery instructions. The import and earlier deployment records below are historical.

## Current baseline — 20 September 2026

The canonical project now contains the 130 AL source files exported from the installed **TAC Pool Master 2.0.0.2** extension in **Pool_Sandbox** on 20 September 2026. All 130 files were verified byte-for-byte against the export. This is a source import and review only: no engine fix, compilation or deployment was performed for this import.

See [LOCAL-ASSESSMENT-20260920.md](LOCAL-ASSESSMENT-20260920.md) for provenance, the confirmed production-order grower mapping defect, related source findings and the proposed correction scope.

The previous local baseline was backed up before import. Two supplementary local AL files absent from the export were retained unchanged and are identified in the assessment. Existing launch settings were retained; generated build metadata was removed from the imported manifest. Old packages under build are historical and do not represent this imported source.

## Historical restoration and deployment record — 13 September 2026

The remaining sections describe the earlier local rebuild and deployment, not validation of the current source import.

Canonical project: D:\WOLFETAC\Cloud\TACPoolMaster

This is DIY-ERP TAC Pool Master 2.0.0.1, app ID 7ce03a80-b797-4aac-af41-7eaa96351ca5, rebuilt from the source export downloaded from TestProd on 11 September 2026. It is not a vendor-supplied binary and does not include engine bug fixes.

Source archive: TAC Pool Master_DIY-ERP_2.0.0.1.zip
Archive SHA256: CE0CA68754E5B4BB2E93A7B1999CBAB64A25BB42938DE578268F1BF0BE2D9707

All 123 AL files were compared byte-for-byte by SHA256 against the archive on 13 September 2026; none changed. Only the generated build metadata was removed from app.json because it is not valid compiler input. Identity, version, runtime and dependencies are retained.

Compiled successfully with AL compiler 18.0.41.45789, Microsoft 28.4 cloud symbols, Microsoft System 28.0.50938.0 platform symbols, and Avocados Core 1.0.1.1 symbols (matching the installed Core version in Pool_Sandbox).

Package: build/DIY-ERP_TAC Pool Master_2.0.0.1.app
Package SHA256: 53E72310286DD17E05332DB23ED7869A7E565EDED518BAE3A5D209DEB3E9C1B6

The install code seeds number series POOL-GRP, POOL-LE and POOL-PAY if missing, creates pool setup if missing, and defaults zero provisional percentages to 40/40/50 in each company. It does not post transactions. Configuration and TestProd pooling data are not migrated by this deployment.

Deployment requested by user: Pool_Sandbox, tenant d000c867-fb80-4af4-9cc1-3655530c967e; schema sync Add; current version. Verification company: LIVE APMS.

## Cloud packaging revision 2.0.0.2

The initial unchanged 2.0.0.1 rebuild failed Pool_Sandbox validation on 13 September 2026: PTE0004, several engine tables lacked matching permission declarations. Added TACPoolTableRead.PermissionSet.al (50297), a non-assignable read-only table permission definition, not included in existing roles and not assigned to users. All 123 original AL files remain unchanged. Manifest version increased to 2.0.0.2. No calculation/posting changes.

Version 2.0.0.2 compiles with PerTenantExtensionCop enabled with zero errors or warnings.
Package SHA256: 2472F935670DDE69A36554FE143D3F5D926B8A62BB65265583CFB43AD2EC2569

## Deployment verified — 13 September 2026

BC Extension Installation Status: TAC Pool Master 2.0.0.2, started 6:00 PM Australia/Perth, Status Completed, Summary: Publish operation completed successfully.

Opened page 59303 in Pool_Sandbox / LIVE APMS after installation. Overview reports Group headers loaded, all seasons/weeks/types selected, 0 of 0 groups. The former missing-table-50230 error is resolved. There are no pool groups in this company to exercise payment or reconciliation checks; financial engine behavior has not been validated. TestProd data was not migrated and no transactions were posted.
