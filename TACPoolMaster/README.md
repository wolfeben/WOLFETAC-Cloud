# TAC Pool Master — restored source baseline

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
