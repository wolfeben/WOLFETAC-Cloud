# Pooling Review architecture

11 September 2026. User requested a custom page inside Business Central for pool checks and drill-downs. This is a separate WOLFE extension at D:\WOLFETAC\Cloud\PoolReview, not a change to TAC Pool Master calculations.

Reserve production object band 59300-59349 and test codeunit 58890. This recorded decision adds the Pool Review domain. Verify installed tenant object availability before first publication.

The extension reads current-company pooling and standard records through a schema-checked read adapter. No Pool Master symbol package is available locally; the adapter checks each required table and field name/type at runtime and fails closed on schema or permission failures. It never invokes Pool Master codeunits or its reconciliation. No financial or source-table writes, no install/upgrade subscribers, no APIs, no background jobs.

All review groups, facts, issues and evidence fields are TableType Temporary. Review results exist in the user session only. The UI has no close, post, resume, create missing or repair actions. Source drill-downs are read-only field snapshots, avoiding existing posting actions.

Initial scope: selected group pool/ledger ownership; quantity-movement vs other kilograms; ledger amount totals; recovery signs as review warnings; missing/duplicate invoice PR records with independent season/week/type attribution; incomplete payment headers; explicit unresolvable-source and coverage information. No claim of full financial reconciliation, approval to pay or readiness to close. Source production, freight-rate, template, tax and market-rule validation remain visibly outside initial coverage.

Read existing access rights; do not elevate third-party table permissions. Show failed/limited scans distinctly. Group results are a review snapshot, not a transactionally consistent close approval. Refresh after posting or source changes. No publication is authorized by this build step.

## Overview UI revision — 11 September 2026
The user clarified that the main deliverable is an at-a-glance pooling workspace, with investigations beneath it. Version 0.2.0.0 replaces the main list presentation with a native BC overview worksheet, scoped status cues, filters, batch checks and selected-group information. Financial fixes remain the responsibility of the pooling engine; the review UI reads evidence and reports findings. It does not compensate for or silently repair engine defects.

The prior request to upload was explicitly paused by the user before publication. No upload is to proceed as part of this UI revision. The interactive conversation preview uses example data and is a layout exploration, not a screenshot of BC or live results. Final native BC layout and behavior still require sandbox testing.

## Batch Labels branding — 11 September 2026
Version 0.3.0.0 adds a branded graphical BC control add-in on page59303, using the actual Avocado Collective red wordmark/icon and navy/red styles from Batch Labels. It retains the native worksheet as a standard review list. This is the same in-BC custom-screen approach as the label pages; there is no hosted service, external data connection or client-side financial calculation. The AL page maintains temporary groups/issues and sends a bounded display snapshot to the frontend. Frontend actions are allowlisted read/check/evidence actions only. All pooling engine code remains unchanged and upload remains paused.
