# WOLFETAC Cloud project setup

## Current target

- Repository workspace: `D:\WOLFETAC\Cloud`
- Business Central environment: `TestProd`
- Environment type: Sandbox
- Application: Business Central 28.3
- AL runtime: 17.0
- Object range: 58000-58999
- First functional focus: SAL Stock & Logistics

This is a Cloud per-tenant extension. The on-premises Packing Wall, Packing Facility Operator, scanner, pallet records and dispatch implementation remain in their own extension.

## First-time local setup

1. Install the Microsoft AL Language extension in VS Code.
2. Copy `.vscode/launch.example.json` to `.vscode/launch.json`.
3. Put the TestProd tenant ID in the local `launch.json`. Do not commit that file.
4. In VS Code, run `AL: Download Symbols` and complete the Microsoft sign-in.
5. Confirm `.alpackages` contains Microsoft System/Application/Base Application symbols and `Avocados Core`.
6. Run `AL: Package` (`Ctrl+Shift+B`) before creating the first commit containing AL source.

Download symbols again whenever an `app.json` dependency changes or TestProd is upgraded.

## Safe sandbox publishing

- Use `schemaUpdateMode: Synchronize` for routine development.
- Do not use `ForceSync` on a shared sandbox unless data loss is explicitly approved.
- F5 may publish only to TestProd while this project is under development.
- Production deployment must be a separate, approved release action.

## Local Git bootstrap

Git is installed. GitHub CLI is not currently installed, and Git author identity must be supplied rather than guessed.

```powershell
Set-Location 'D:\WOLFETAC\Cloud'
git init -b main
git config user.name 'Ben L'
git config user.email '<a GitHub-verified email address>'
git status --short --ignored
git add .
git diff --cached --check
git diff --cached --stat
git commit -m 'chore: initialise WOLFETAC Cloud extension'
```

The real `.vscode/launch.json`, symbol packages, compiled `.app` files and credentials must not be staged.

## Create and connect GitHub

Preferred immediate method, because GitHub CLI is absent:

1. Create an empty **private** GitHub repository named `WOLFETAC-Cloud`. Do not add a generated README, licence or `.gitignore`.
2. Copy its HTTPS URL.
3. Run:

```powershell
Set-Location 'D:\WOLFETAC\Cloud'
git remote add origin https://github.com/<owner>/WOLFETAC-Cloud.git
git remote -v
git push -u origin main
```

Alternatively, after the local commit, use VS Code's `Publish to GitHub` command and choose **Private repository**.

Never put a personal access token in a command, file or Git remote URL.

## Working workflow

1. Keep `main` releasable.
2. Create a short-lived branch such as `feature/sal-plan-model`.
3. User and ChatGPT define the bounded feature and acceptance criteria.
4. GitHub Copilot implements the AL and tests in VS Code.
5. Claude reviews the diff against `CLAUDE.md` and the SAL boundary.
6. Resolve findings, compile locally and publish only to TestProd.
7. Luke performs the agreed acceptance test.
8. Merge by pull request, preferably using squash merge.

Do not introduce a long-lived `develop` branch initially.

### Claude review command

Run Claude Code from the repository root so it automatically loads `CLAUDE.md`:

```powershell
Set-Location 'D:\WOLFETAC\Cloud'
claude
```

Then enter:

```text
/code-review high
```

For non-interactive output, use `claude -p "/code-review high"`. Do not add `--fix`; Claude is the independent reviewer and Copilot performs any agreed corrections.

## GitHub protections

After the first push, add a `main` branch ruleset:

- block force pushes and branch deletion;
- require a pull request;
- require the build check after CI is added;
- require conversations to be resolved;
- add a required human approval only when it will not lock the repository owner out.

## CI/CD

First achieve one clean local package. Then add Microsoft AL-Go for GitHub using the AL-Go-PTE template and its existing-PTE process. Start with build and test only. Add TestProd deployment later through a protected GitHub Environment using service-to-service authentication. Production stays manual and approved.

- AL-Go: https://github.com/microsoft/AL-Go
- PTE template: https://github.com/microsoft/AL-Go-PTE

Do not invent a custom `alc.exe` GitHub Actions pipeline before evaluating AL-Go.

## First implementation milestone

The first branch is `feature/sal-plan-model`. Its outcome is:

1. persistent SAL Plan Header, Source, Pallet, Component and Event tables;
2. execution route and facility work type enums;
3. setup and permission sets;
4. a minimal Planner page that saves a draft;
5. validation tests for totals, pallet sequences and source references;
6. no on-prem publication yet.

The second milestone adds the versioned Facility Work Package and an acknowledgement round trip. It must prove that a Manjimup packing plan reaches the facility while an inter-DC transfer never appears on the Packing Wall.
