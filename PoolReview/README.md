# TAC Pool Review — team handover

Built 11 September 2026. **Version 0.4.0.1 published successfully to TestProd on 12 September 2026.** Initial runtime checks passed in company Avo Setup: the branded page loaded, both available groups completed checks, and three payment headers loaded for PG-2026-W08-I. Full acceptance testing and execution of the separate AL test suite remain outstanding.

The branded **Pooling Overview** page is part of a separate WOLFE extension. Version 0.4.0.0 uses the actual red Avocado Collective wordmark and icon, navy headers/footer and label-screen styling. The former native worksheet remains available as **Pooling Review List**. It reads pooling records in the current company and creates temporary review results. No pooling calculation, posting code or financial record was changed.

After an approved sandbox installation, search for **Pooling Overview** (page59303), set the season, pool week and type filters. The overview cards show all groups in scope plus five separate review categories. Click a card to focus the list. Select a group and choose **Check this group**, or use **Check current list** for a focused list of up to 50 groups. The group search searches only the displayed rows; clear it before checking the whole list. Unchecked and failed scans show dashes for unavailable totals. Expand a finding under **Findings & evidence**, then choose **View source** or **Related record** to inspect current field snapshots. Reloading the list or closing the page clears session results. Record snapshots may differ from the original scan if data changes.

| Area | What this version shows | Interpretation |
|---|---|---|
| Group overview | Clickable status cards, season/week/type filters, business status, scan time, pool counts and kilogram totals | Five review categories partition all groups in scope. Cards respect season, week and pool type; card focus narrows the list only. |
| Pool ownership | Ledger Group ID versus its nonblank pool's current owner | Mismatch in visible records; investigate posting or reassignment history. Blank group-level pool codes are allowed. |
| Product classification | Available ledger variety/grade/size dimensions versus assigned pool | Resolved differences are mismatches. Incomplete PR/FR/TR/TRA/TRD classifications count as unresolved. Grower identity and physical-source allocation are not fully validated. |
| Kilograms | Raw signed TR + TRA + TRD kg versus raw signed all-entry kg | Different bases need review. Reversal signs are preserved. Neither total is certified physical quantity. |
| Invoice revenue | Independently enumerated candidate invoice lines, active PR matches, processed-state markers, legacy matches and wrong group allocations | Distinguishes missing, multiple and ambiguous evidence. Multiple PRs are a warning, not automatically duplicate revenue. |
| Payments | Positive unreversed PP/PPV entries and payment headers without completion times | Recovery/completion review indicators. No claim of overpayment or failed payment without document reconciliation. |
| Coverage | Unresolved counts, read failure detail, exact included/excluded scope | Schema, access, missing setup and scan-limit failures discard partial results. A completed scan does not approve closing or payment. |
| Drill-downs | Source and related record fields, read-only | No posting, repair, resume, close or source-edit actions. |

## Included source scope

- Pools owned by the selected group.
- Ledger records whose recorded group is selected, plus records referring to a pool owned by the selected group, plus matched active invoice PR evidence. Entry No. deduplication prevents counting the same entry twice.
- Payment headers recorded against the selected group.
- Posted Item invoice lines with a nonblank consignment and stored season/week matching the selected group. The candidate count is before type attribution and includes other pool types.
- Invoice attribution requires a unique visible pool week for season/week, a unique group for week/type, and exactly one matching consignment/item/season/week. Pool type comes from consignment dimensions. Required invoice dimensions must be present before asserting a missing PR.
- Matching is the disjoint union of PR/Sales Invoice/unreversed entries with the line SystemId and blank-GUID legacy entries with exact source document/line. A different populated GUID is not accepted. Processed state is checked independently by invoice header SystemId.
- All access is in the current company under the user's existing source permissions. Results cover visible records, not records hidden by security filters. They are a sequence of reads, not an atomic snapshot.

## Limits and next development

This version does not inventory missing-season/week invoice lines, production output sources, sales credits, adjustments/expense preflight, freight rates, charge-template ties, duplicate deductions, market rules, taxes, report datasets or purchase/payable reconciliation. It also does not certify grower/vendor identity, historical allocations or payment amounts. The revised business scope has not been confirmed.

Results are session-only; there is no saved review history, assigned owner, notes, scheduled scan or automated fix. The branded page includes internal overview/findings CSV downloads and a CSV of the loaded payment headers. These are review snapshots, not grower statements or tax invoices.

There is a 5,000 group selection limit, a 50-group batch limit and a 25,000 evidence-record limit per group scan. A limit failure stops the operation rather than presenting truncated results as clear. Performance and permission behavior require acceptance testing with representative sandbox data.

## Build and permissions

Canonical source: `D:\WOLFETAC\Cloud\PoolReview`.
Extension: `TAC Pool Review`, publisher `WOLFE`, ID `91fac4f6-4862-4b6a-83bf-b7c89edb5930`, version `0.4.0.1`.
Production IDs: 59300–59349 reserved; test codeunit 58890.
Run `Build.ps1` locally to compile both apps and perform structural read-only checks. It performs no publication.

Assign `WLF POOL REVIEW` plus the user's existing authorised source-read permissions. This permission set grants only the new objects and temporary buffers; it does not elevate Pool Master access. Required sources include tables 50230, 50220, 50208, 50209, 50225, 50206, 50233, 50239 and standard posted sales invoice/dimension data.

A Pool Master symbol package was unavailable locally. The adapter consequently uses read-only RecordRef access with checks of table/field names, field types and enum member meanings. The reviewed schema is TAC Pool Master 2.0.0.1; a compatible schema is not proof that a later engine has identical business rules. Confirm installed extension version, runtime compatibility and object availability before sandbox publication. No dependency on copied on-premises custom apps is included.

## Validation and sandbox acceptance

Local compilation and static checks are recorded in `build/compile.json` and `build/read-only-checks.json`. The separate `Cloud/Test/PoolReview` app contains 20 test methods (18 temporary-fixture rule checks and two CSV escaping checks). **Compilation is not execution: the AL test methods and page have not run in BC.**

Before team acceptance in a sandbox:

1. Install both apps after checking IDs and dependencies; run codeunit 58890 with the test runner and retain results.
2. Open the page under a source-read-only user. Verify that source table counts, records and posting registers remain unchanged after scanning and opening evidence.
3. Check representative Internal, External and Contract Pack groups against manually reviewed source records.
4. Exercise an invoice with one exact PR plus one blank-GUID legacy PR; inspect multiple matches and wrong-group allocations, including PRs entirely outside the selected group.
5. Exercise missing processed invoice PR, ambiguous consignment, duplicate season/week definitions, missing dimension setup, missing read permissions and scan-limit failures. Confirm no partial-clear result is shown.
6. Compare signed kg totals including original and reversal rows; confirm source values are not double-inverted.
7. Check current company, timestamps, per-group issue isolation, repeat scans and source/related drill-down behavior; measure representative scan duration.
8. Verify the branded overview layout, logo resources, editable filters, status-card counts and empty-list behavior. Check the control add-in handshake and return from evidence dialogs in BC; the local preview cannot validate these. Also check the retained native review list. Check that the five categories sum to Groups in Scope. Batch-scan a Not Checked focus and confirm every captured group is checked even as rows leave that focus. Verify a batch above 50 is rejected before scanning.

A successful sandbox result and business review are still required before any production release.




## Branded graphical UI
Page 59303 hosts packaged HTML/CSS/JavaScript through a BC control add-in. The exact branding assets are copied from BatchMain's existing label UI; those source assets and the BatchMain extension are unchanged. No external website, CDN, font service or API is used. All source reads and checks remain in AL under the existing user permissions.

The UI receives a display snapshot and sends only allowlisted actions with typed payloads. Source evidence is resolved from the selected issue on the server; the browser cannot submit arbitrary RecordIds. The list shows up to 200 groups and explicitly reports any remaining count; findings show up to 500 with an explicit limit notice. Narrow filters to inspect remaining records. Batch checks cover the whole focused list and reject more than 50 groups before starting.

The standard review list maintains a separate temporary session if opened; its check results are not shared back into the branded overview. A page reload clears this page's session results. Load/schema/read failures remain explicit and incomplete results are not presented as complete.

`preview/example-bridge.js` and `preview/Build-Preview.ps1` are local visual-test tools using invented example data. They are not packaged as control-add-in resources and do not connect to BC. The generated preview uses the production UI assets, but does not validate AL server behavior. Local browser checks covered status/week filters, group selection, evidence-button routing in the example bridge, empty results, unchecked/failed dashes and layouts at 320, 360 and 1024 pixels. No browser warnings or errors were reported in these checks. All 20 AL test methods still require BC execution.


## Reporting and payment history — version 0.4

Choose **Pool payments** beside **Findings & evidence**, then **Load payment history**. This reads the selected group payment headers independently of the broader review checks. Expand a run to see its type, sequence, provisional flag, pool, closed/completed times and users, reversal reference, journal batch and stored purchase-invoice references. **View payment header** opens the existing read-only field snapshot. Completion is a run marker, not proof of bank settlement; no paid amount, outstanding balance or due-date calculation is inferred.

History loads a maximum of 200 headers and displays the visible total and an explicit truncation notice. Its own load time is shown. A failed load discards partial history and disables payment export. Selecting a different group or reloading the overview clears the prior payment history. Header drill-down accepts only an ID in the currently loaded group snapshot and rechecks the live header's group membership and user access.

**Export overview** and **Export findings** include every group matching the current season/week/type/status filters, beyond the 200 displayed-group limit. They use existing session checks, with company/environment, export time, scope, coverage and the number of groups without a complete scan. Clear the local group search first. Blank numeric measures identify unavailable checks; nonnumeric classification findings omit placeholder comparisons and recovery findings do not imply a zero expected payment. Findings export has a 50,000-row limit and fails before downloading any partial file.

**Export loaded payments** exports only the currently loaded payment-header rows, with total/truncation metadata. All downloads are UTF-8 CSV, with quoted text and spreadsheet-formula neutralization. No files are emailed or sent elsewhere. The original Pool Return and Pool Group Summary report datasets were not changed or wired into this release; grower-facing financial documents need their own report review.

Local validation: both 0.4 apps compile without compiler issues; read-only structural checks pass. Browser example-data checks exercised payment loading, switching groups, completed/reversed/unfinished states, empty and failed histories, payment-source routing and export action routing. The narrower layouts fit at 360 pixels. The preview does not download actual BC reports or validate server data. Sandbox acceptance must verify the real CSV downloads (Unicode, commas, multiline text and formula-like text), exact filter coverage beyond displayed limits, schema/permission failures, header evidence, and both CSV test methods.


Version 0.4.0.1 adds a Full screen / Exit full screen button in the masthead. It uses the standard browser Fullscreen API and updates when the browser exits (including Escape). It does not reload or rescan data. The exit button remains usable during a check. It exits fullscreen before opening BC evidence dialogs or downloads so those remain visible. Browser/iframe permission can prevent fullscreen; the UI explains this instead of claiming to expand. Actual BC hosting support requires sandbox testing. Reference: https://developer.mozilla.org/en-US/docs/Web/API/Element/requestFullscreen

## TestProd publication — 12 September 2026
Published the verified production package through Extension Management with Current version and Add schema mode. Status: Completed; summary: Publish operation completed successfully. Installed Pool Master is 2.0.0.1. Smoke check: page 59303 loaded; 2 groups scanned with 0 incomplete scans (one group with 9 mismatches, one with 4 review indicators). These findings are not yet independently reconciled. Payment history loaded 3 headers. Test app was not installed or executed. VS Code settings now reuse SAL's TestProd tenant and Synchronize configuration, with startup page 59303.


## Scrolling correction — version 0.4.0.2
Published successfully to TestProd on 12 September 2026. BC hides overflow on the control-add-in body; the root now owns viewport-bounded scrolling. Verified in BC at a 600px embedded height: content height 2135px, scroll reached the bottom and footer was visible; returned to top. Fullscreen entered and exited through the UI. Both apps compile and structural checks pass. No pooling rules changed.


## Linked ledger evidence — version 0.5.0.0
Payment, group and pool source snapshots now include **Linked ledger entries**. The read-only temporary list shows stored signed Amount and GST Amount, kilograms, posting date, transaction type, grower, pool, recorded group, payment ID, source document reference, reversal flag, posted-to-G/L flag, G/L entry reference and comment. **Entry evidence** opens the full source snapshot for the selected ledger row.

Payment selection filters ledger field 35 by the exact payment header ID. Group selection filters recorded group field 25; pool selection filters pool code field 2. All transaction types and reversal rows are included. Wrong-group rows linked to a payment are retained and display their recorded group. The view validates field names/types and existing source read permissions, rereads the selected source, and rejects more than 25,000 rows before opening. It does not infer bank settlement, currency, outstanding balances or purchase-document reconciliation. A source document number is a reference, not an automatically resolved posted invoice link. No engine rules or financial records are changed.

Validation on 12 September 2026: production and test apps compiled at 0.5.0.0 and read-only structural checks passed. TestProd reported publish completed successfully (started 11:33 AM Perth). In Avo Setup, Payment ID 8 opened linked ledger rows with Payment ID 8, including entry 149 (APMS). The list showed amount 31.56 and GST 3.16; Entry evidence correctly exposed stored amount 31.556, VAT Amount 3.1556, Pool Payment ID 8 and entry number 149. List formatting rounds amounts for display; full evidence retains source precision. The new list and nested evidence navigation were checked in the live UI. AL test codeunits were compiled but not executed in BC.

## Native source navigation - version 0.6.0.1

Open in Business Central opens the live native page inside the current BC session with the exact key filter. Users can use the native pop-out control for a separate window. This avoids relying on automatic popups, which did not appear in the embedded browser during the 0.6.0.0 smoke check. Mappings cover pool group, week, pool, ledger entry, consignment line to its header, and posted sales invoice line to its header. Payment headers open their owning pool group, because the installed engine has no standalone payment header page. Page name and source-table metadata are checked before navigation. Normal source permissions and native actions apply; review pages still make no business-table writes. Source-page actions are outside the review workspace.

Open originating document on the linked ledger list supports posted sales invoices, posted credit memos, consignments and expenses. It verifies the source-type enum, follows the stored line System ID, then opens the matching header. Missing IDs, missing records and unsupported source types produce an explanation; no number-only fallback or guessed document is used. No corrections, reversals, posting or engine reruns are performed by these links. Refresh/recheck the review after any source changes.

Implementation follows the RecordRef-to-Variant Page.RunModal pattern in the installed Microsoft Page Management codeunit. Production and test apps compile; structural read-only checks pass. AL tests have not executed in BC.

Runtime validation, 13 September 2026: TestProd completed publication of 0.6.0.1 (deployment started 4:18 PM Perth). From Avo Setup review evidence, Open in Business Central opened native Pool Group 7. From the linked ledger list, selecting entry 164 opened the native Pool Ledger Entries page with an exact Entry No. filter; the live input values were Entry No. 164 and Amount 302.57. Closing each native page returned to the review. Entry 23 returned the intended unsupported-origin explanation without opening a substitute document. Positive originating-document branches require suitable source System IDs and were not exercised on these historical sample records. No business records were edited or posted during validation. Automatic popup behavior in 0.6.0.0 was not verified; 0.6.0.1 opens the native page in the current session. Native page pop-out behavior was not tested.
