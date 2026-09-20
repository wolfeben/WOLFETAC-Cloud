# Release on hold: review payment rules first

## Temporary legacy-code reuse authorised by Ben

Ben subsequently requested: "allow it to put the same code in for now like it was and we test and see how it impacts". This authorises the focused 2.0.0.7 sandbox release described in `LEGACY-POOL-REUSE-2.0.0.7-HANDOVER.md`: retain the exact-match lookup, then reuse an existing generated Pool Code instead of attempting a duplicate insert. This deliberately restores the old fallback and can combine different grades/sizes under the original pool header. It does not establish the final pooling design. The active source is now this candidate, based on released 2.0.0.3; consult its handover for publication status.

Version 2.0.0.7 is now published to Pool_Sandbox; four named focused native checks passed in LIVE APMS, with fixture absence verified in a subsequent call. The sequence/GUID proposal 2.0.0.5 and its 2.0.0.6 recovery remain held. No new uniqueness index, schema change, close/payment consolidation or broader review fix is included. Recovery 2.0.0.8 restores all 2.0.0.3 AL behaviour, including its grower-dimension fix, but cannot undo business data created during the trial. Earlier hold sections below are historical context; the explicit temporary fallback authorisation takes precedence for this narrow release only.

## Pool identity proposal also held

Ben subsequently asked to establish why older code allowed multiple postings to one code and raised concern that adding a sequence could break other behaviour. Identity candidate 2.0.0.5 and recovery 2.0.0.6 are **not published**. The active engine source is restored to released 2.0.0.3. Read `POOL-IDENTITY-HISTORY-20260920.md` before further identity changes. Do not publish either candidate or add the proposed uniqueness index until the grouping question is resolved. The earlier grower-only release remains installed.

Ben clarified that the intended pool combines product costs and sales into an average shared across growers. Current creation includes the grower in pool identity, while settlement totals by Pool Code. The held candidate preserves that separation and therefore is not a complete solution to the intended pooling model. Record the grower on contributions; review shared financial-pool membership before changing identifiers or restoring the old fallback.

## Narrow exception authorised by Ben

Ben subsequently requested publishing **only the grower-code fix** to Pool_Sandbox so Josh can continue testing. The broader 1–26 release and all close/payment changes remain held. The active source has been reset to the verified installed baseline plus the three-codeunit grower fix; the full WIP is preserved in `D:/WOLFETAC/.snapshots/PoolMaster-grower-only-20260920/deferred-full-work-in-progress.zip`. See `GROWER-FIX-2.0.0.3-HANDOVER.md` for the current status. The notes below record the earlier broad-release hold, not a prohibition on the explicitly requested grower-only release.

## Earlier broad-release hold

Ben explicitly requested review of the intended payment rules before changing close code on 20 September 2026.

Latest instruction: defer that section and return to it later. Treat the workflow/payment-policy difference as a deferred business-rule question, not a confirmed bug. Exclude the F16 / item 18 consolidation proposal from the current fix scope and preserve the existing close workflows. Do not request a policy decision merely to complete unrelated fixes. Any future candidate containing other fixes must demonstrate that it leaves the deferred close behaviour unchanged before this release hold can be reconsidered.

No Pool Master update has been published. Installed engine remains 2.0.0.2.

The proposed consolidation has been removed from the active local build. Original pool close, group close, G/L close posting, pool page actions and payment header source have been restored from the verified installed package. The proposed changes are preserved in the snapshot:
`D:/WOLFETAC/.snapshots/PoolMaster-release-20260920/unapproved-close-proposal-20260920.zip`.

Other local fixes remain work in progress, compiled but NOT runtime-tested or approved for publication. Do not publish this directory as a finished release. Do not re-run build/apply_close.py or build/apply_postpool_manual_reports.py without first resolving the payment-rule review.

Required review: payment schedule vs Pool Payment Setup percentages; Retention vs Full Payout; pool vs group close scope; interim estimates; provisional counts; reversals/recoveries; final residual; grower charges. Distinguish intended financial rules from posting-state defects. Earlier broad authorization for fixes 1–26 does not authorize changing payment policy.

Review recorded in `PAYMENT-RULE-REVIEW-20260920.md`. Available scope and installed code do not establish which of the two payment configuration systems should govern both workflows. The release hold remains in place.
