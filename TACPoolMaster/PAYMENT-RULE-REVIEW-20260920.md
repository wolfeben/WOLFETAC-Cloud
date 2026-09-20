# Pool payment rules: review before changing close code

20 September 2026 | Pool_Sandbox / LIVE APMS | TAC Pool Master 2.0.0.2

**Deferred by Ben:** return to this section later. Differences between the close workflows/payment policies may be intentional and must not be presented as a confirmed bug. Item 18 / F16 consolidation is outside the current fix scope. Preserve the existing close workflows and payment rules; the analysis and questions below are retained for that later discussion, not as a request for a decision now.

**Conclusion: consolidating individual-pool close into group close is a business-policy decision as well as an implementation change. Do not include it as an automatic correction to finding F16 (item 18 of the 26).** Both routes expose provisional and final closes; they operate at different scopes and read different payment configuration.

Ben requested this review before further close-code changes. The proposed consolidation has been removed from the active local source and preserved in a snapshot. No Pool Master update has been published. Other local fixes remain work in progress and are not a release candidate.

## Evidence and limits

- The available [RFS — Pool Manager V1.1](<C:/Users/BenL/OneDrive - IXODIGITAL PTY LTD/Client Files/AVOS/outputs/july-invoice-review/365 Business Pty Ltd t_a DIY-ERP - Sales Quote 1079/RFS - Pool Manager V1.1.docx>), dated 22 June 2026, describes group close, kilogram-based distribution, provisional advances through vendor entries and the standard payment run, grower purchase invoices and validation before posting. It does **not** specify the detailed retention/full-payout formulas or resolve the two configuration systems.
- The installed-package source contains a more detailed `C-07 [v2.0]` design comment explicitly describing Retention and Full Payout. This is evidence of implementation intent, **not proof of the latest approved business scope**. Other comments refer to design sections and decisions whose complete documents were not located.
- Local document searches and the available Notion searches did not establish a revised approved payment specification. This does not establish that no such document exists.
- The core close routines, their setup/schedule tables and pages, the pool card and payment header were checked against the verified 2.0.0.2 package and match it, ignoring line endings. Package SHA256: `e8b4cbaa18425a51bc25e0c46e6f31b362dceee7f8f2a0cdf8cc5f48f1a81b4d`.
- This is a source and document review. It does not validate current live setup values, execute a payment, or establish that a historical payment was wrong. “Already paid” in these formulas means recorded PP/PPV pool ledger amounts; it is not an independent check of money cleared through the bank.

## Rules the installed code actually implements

| Topic | Individual-pool close | Pool-group close | Implication |
|---|---|---|---|
| Scope | One selected pool. | Pools belonging to the selected group. | Moving a pool action to group close can affect other pools. |
| Provisional percentage | Active Pool Payment Schedule row for the pool type and sequence; uses **Cumulative Share %**. | Pool Payment Setup: Internal first percentage, then first + second; External uses its first percentage. | Different settings can produce different payments. |
| Retention | Scheduled cumulative percentage of realised net, less earlier pool payments. | Uses its own cumulative percentages, less earlier pool payments. | Broadly similar formula, but neither configuration automatically governs the other. |
| Full Payout | A pool's Payment Model can set the target to 100% at each close. | Does not read the pool's Payment Model or the Payment Schedule. | Consolidating into the existing group routine could remove a deliberate full-payout choice. |
| Final amount | Realised net less earlier pool payments; requires the configured final sequence. | Targets 100% less earlier pool payments; does not use the schedule's final sequence. | Similar residual principle, different sequence requirements and surrounding charges. |
| Number of advances | Governed by schedule rows, although the pool/group counter mismatch is a defect. | Maximum two provisional closes for Internal, one for External; Contract Pack is blocked. | Keep this policy separate from fixing the counter and resume defects. |
| Timing | Schedule exposes Offset Weeks, but no engine reference enforcing those offsets was found. | No schedule-based timing check in the close routine. | A displayed due offset should not be presented as an enforced payment date. |
| Estimates and unpriced fruit | Provisional close has an unpriced-fruit check/override and reverses/reposts interim G/L estimates. The payment calculation itself reads the pool ledger. | No equivalent interim-estimate routine in group close; some completion checks remain TODOs. | Do not silently add estimated revenue to grower entitlement or remove an intended interim accounting step. |
| Financial documents | Writes payment ledger entries and direct G/L entries; no grower purchase-document creation in this route. | Creates a payment header, posts G/L and builds grower purchase documents. | This is an integration gap to resolve against the intended supported workflow. |
| Failure recovery | Design comment says the close should be one transaction. | Includes a staged recovery action for G/L posted before invoice completion. | Atomic posting is supported by the available design text, but a reliable implementation must also handle pre-existing incomplete runs. |

Code evidence: [individual close and C-07 calculation](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Post Pool_.Codeunit.al:373>), [group calculation](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool Group Close_.Codeunit.al:324>), [setup percentage calculation](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool Setup_.Table.al:265>), [schedule fields](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool Payment Schedule_.Table.al:35>), [G/L and invoice stages](<D:/WOLFETAC/Cloud/TACPoolMaster/_TAC Pool GL Posting_.Codeunit.al:24>).

## Simple illustration

Assume an unchanged realised net entitlement of $100,000, no additional charges, no previous payments, and a schedule of 40%, 80%, then 100% cumulatively. These are illustrative settings, not a reading of the company's current configuration.

| Stage | Retention: amount paid at this stage | Full Payout: amount paid at this stage |
|---|---:|---:|
| First provisional | $40,000 | $100,000 |
| Second provisional | $40,000 | $0 |
| Final | $20,000 | $0 |

If the entitlement changes between closes, each close recalculates its target using the new net amount and deducts earlier payments. For example, after paying $100,000, a final entitlement of $90,000 produces a **$10,000 recovery balance**. Whether that is recovered immediately, carried forward or handled another way needs an approved business rule. Turning its sign into a further $10,000 payment is a posting defect regardless of the chosen recovery workflow.

## Defects to correct without choosing a new payment policy

| Original item | Defect or concern | Boundary for the fix |
|---|---|---|
| 15 / F13 | Purchase-document construction takes absolute payment amounts, losing recovery direction. | Preserve the signed obligation; agree the recovery document/workflow before implementing it. |
| 16 / F14 | Grower value-charge logic uses signed accumulated payments and the first eligible-looking template. | Resolve the intended fee base: this payment, cumulative entitlement or another basis. Then correct sign and template matching. |
| 17 / F15 | G/L amount handling can lose reversal direction. | Preserve the configured accounting direction for payments, charges and reversals. |
| 18 / F16 | Individual close advances the pool counter but validates against the group counter; the paths also differ in document creation and posting flags. | Fix state consistency within the supported workflows. Do not assume the two payment policies should be merged. |
| 19 / F17 | Individual final close does not clear interim revenue left by a provisional close. | If that interim model is retained, reverse the outstanding estimate once with the correct source/dimensions. |
| 20 / F18 | Posting flags can cover entries beyond the exact successfully posted set. | Track the entries belonging to the posting run; retain a visible incomplete state for failures. |
| 21 / F19 | Resume rejects a provisional run when the group is already Provisionally Closed, which also describes an interrupted second provisional. | Distinguish a completed first run from an incomplete second run; preserve the allowed number of advances. |
| 22 / F20 | Group status validation checks the wrong record state in find/create. | Correct the record reference; separately confirm whether new activity after provisional close is allowed. |
| 26 / F24 | Unpriced-fruit validation relies on a header FlowField without calculating it and does not prove each line is priced. | Make the agreed completeness rule reliable. Do not invent a stricter payment eligibility policy. |

Source evidence and activation conditions are retained in [the broader review](<D:/WOLFETAC/Cloud/TACPoolMaster/BROADER-REVIEW-20260920.md>). These are source findings, not newly executed end-to-end tests.

## Decisions needed before implementing the close changes

1. **Supported workflow:** are both pool and group closes intended for accounts users, or is one legacy? If both remain, how may they be used together for the same group?
2. **Payment authority:** should group close honour each pool's Payment Model and Payment Schedule, or deliberately use the separate Pool Payment Setup percentages?
3. **Advances and estimates:** are advances based only on realised ledger value, or may an estimated value contribute? What must be priced/finished, and what timing or override is allowed?
4. **Fees and recoveries:** what is the grower fee base, and how should an overpayment be recovered? What happens to adjustments after final close?

Recommendation: preserve the existing percentage, model and sequence choices while those decisions are resolved. Design shared posting safeguards only after the financial inputs and scope are explicit. Any eventual release needs failure/retry and payment-calculation verification as well as a proven rollback package; compilation alone is insufficient.

See [release hold](<D:/WOLFETAC/Cloud/TACPoolMaster/RELEASE-HOLD-20260920.md>). No close-code change or deployment is authorised by this review itself.
