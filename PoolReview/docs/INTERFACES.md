# Implementation contract
Tables/enums are src/ReviewBuffers.al and ReviewEnums.al. All tables have TableType Temporary.

Read adapter 59300 WLF Pool Review Read (root owned):
- LoadGroups(var Groups: Record "WLF Pool Review Group")
- RunChecks(var Group: Record "WLF Pool Review Group"; var Issues: Record "WLF Pool Review Issue")
- ShowEvidence(SourceID: RecordId)
- CoverageNotes(): Text

Rule engine 59301 WLF Pool Review Rules:
- Evaluate(var Group: Record "WLF Pool Review Group"; var Facts: Record "WLF Pool Review Fact"; var Issues: Record "WLF Pool Review Issue")
- AddIssue(var Group; var Issues; RuleID:Code[20]; Severity:Enum "WLF Pool Review Severity"; Summary:Text; Details:Text; Fact:Record "WLF Pool Review Fact"; Expected:Decimal; Actual:Decimal; Measure:Text)
Root clears existing issues for selected group before Evaluate. Issue No must be globally unique among current temporary records, find last with reset filters.
Facts membership: Pool records for selected group (Owner Group ID = real group); Ledger records whose recorded group is selected OR whose actual Pool owner is selected. Preserve actual recorded Group ID and resolved Owner Group ID. No duplicates; use actual ledger record ID. Invoice facts only candidate lines for same selected season/week and group type; unresolved group type/classification included as Attribution Resolved=false, NOT definitive missing revenue. Candidates scoped independently of state marker. Matching Entry Count (PR) uses source SystemId first then exact doc/line fallback marked Legacy Match; only unreversed entries count. Has Invoice State separately populated. Source Record ID identifies live source evidence, Related Record ID identifies related pool or ledger when unambiguous.
Pool facts: Description and Actual Classification as V/G/S string.
Ledger fact: Expected Classification holds source dimension V/G/S only when all configured dimensions resolved; Actual Classification holds assigned pool V/G/S; never compare blanks as a known mismatch.
Payment fact: payment ID, completion, reversed, source record ID, group.
Group counters reset by root before scan. Rules compute amounts/counts from Facts with recorded Group ID==selected for group ledger totals; ledger ownership exceptions also inspect incoming wrong-group facts. Invoice counters set by root, including candidates, attributed and unresolved. Rules increment errors/warnings/info. Group Scan Complete means adapter completed bounded reads, not full financial reconciliation. Page shows exact scope.
No static developer bugs masquerading as live errors. No Pool Master codeunit calls or source/business table writes.


Fact field30 Invoice Group ID is the independently attributed source group on matched ledger facts when an invoice has multiple PR matches. Rules inspect those facts even when recorded/owner groups both differ; aggregate ledger totals still use only recorded selected group.


Version 0.4: Reader.PaymentHistory(GroupID): JsonObject; Reader.ShowPaymentEvidence(GroupID, PaymentID). Export codeunit59302 DownloadReview(var Groups, var Issues, Kind, EnvironmentName, ScopeText) preserves caller group filters; DownloadPayments(Payments, EnvironmentName, GroupCode) exports only loaded bounded headers. No business mutations.
