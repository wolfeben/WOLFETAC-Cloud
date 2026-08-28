# Claude review instructions for WOLFETAC Cloud

Review the proposed diff; do not redefine the product scope. The user and ChatGPT own requirements and acceptance decisions. GitHub Copilot implements them. Claude independently checks correctness, risk and omissions.

Read first:

- `SAL/ARCHITECTURE.md`
- `docs/OBJECT-ID-REGISTRY.md`
- the issue or acceptance criteria for the branch

Review in this order:

1. **Critical correctness**: data loss, direct writes to posted BC tables, incorrect Sales/Transfer posting, security exposure, cross-company leakage or non-idempotent integration.
2. **Business boundary**: Cloud versus Packing Facility ownership; pack work versus logistics-only work; Sales versus Transfer lifecycle; Unconsigned semantics; marketer and exact mixed-pallet matching.
3. **Upgrade safety**: stable object IDs, keys, field numbers, data migration, obsoletion and rollback implications.
4. **Concurrency and integration**: plan version checks, duplicate messages, out-of-order delivery, acknowledgements, retries, tombstones and reconciliation.
5. **Permissions and audit**: least privilege, actor/time/reason, Finish Short controls and separation of roles.
6. **AL quality**: Cloud compatibility, supported BC APIs/codeunits, `Validate` use, performance, locking, tests, captions, tooltips and data classification.

Report findings with severity, exact file/line, impact and a concrete correction. Distinguish confirmed defects from questions or suggestions. Do not approve a change merely because it compiles.

## Run the review

From PowerShell or the VS Code terminal:

```powershell
Set-Location 'D:\WOLFETAC\Cloud'
claude
```

Then enter this command inside Claude Code:

```text
/code-review high
```

For a one-shot terminal review that prints the result and exits:

```powershell
Set-Location 'D:\WOLFETAC\Cloud'
claude -p "/code-review high"
```

Use `/code-review max` only before a significant merge when its remote multi-agent review, repository upload and possible usage-credit charge are understood and approved. Do not use `--fix` during independent review; implementation corrections belong in a separate Copilot pass.
