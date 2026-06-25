# Self-Sustaining Dependency and Quality Pipeline Plan

This file is the source of truth for implementing the self-sustaining maintenance pipeline in this repository. Any implementing agent should reference this file before making changes, preserve the intent here, and avoid inventing alternate behavior unless the user explicitly revises this plan.

## Goal

Make this repository maintain itself as much as practical:

- Version and lock JavaScript-based tooling.
- Keep GitHub Actions, Docker, pre-commit hooks, and npm tooling updated by Dependabot.
- Run quality checks on every push, pull request, and scheduled health check.
- Auto-approve and auto-merge passing Dependabot PRs with squash merge.
- Leave a durable GitHub signal when scheduled checks fail so the maintainer knows when code or pipeline work is needed.

## Current State

- CI currently runs one `lint` job on `push` and `pull_request`.
- CI uses Node.js 22 and `j178/prek-action`.
- `.pre-commit-config.yaml` contains JS-based tools through mixed mechanisms:
    - `cspell` via the `streetsidesoftware/cspell-cli` pre-commit repo.
    - `markdownlint-cli2` via the `DavidAnson/markdownlint-cli2` pre-commit repo.
    - `markdown-table-formatter` through floating `npx -y markdown-table-formatter`.
- There is no `package.json` or lockfile today.
- Dependabot currently tracks `github-actions` and `docker` weekly.
- A separate pre-commit autoupdate workflow exists and should be replaced by Dependabot's `pre-commit` ecosystem.
- The active default-branch ruleset already requires one PR approval and squash-only merge methods, but it does not currently require `lint`.

## Implementation Requirements

### Add Locked npm Tooling

Create npm tooling state for repository maintenance only:

- Add `.npmrc` with `save-exact=true`.
- Add a private `package.json`.
- Add a committed `package-lock.json`.
- Install exact dev dependencies:
    - `cspell`
    - `markdownlint-cli2`
    - `markdown-table-formatter`

Use npm only for quality tooling. Do not introduce application code, build output, runtime packaging, pnpm, or yarn.

### Update pre-commit Configuration

Update `.pre-commit-config.yaml` so JS tools are local hooks backed by `node_modules`:

- Replace the `streetsidesoftware/cspell-cli` pre-commit repo with a local `cspell` hook.
- Replace the `DavidAnson/markdownlint-cli2` pre-commit repo with a local `markdownlint-cli2` hook.
- Keep `markdown-table-formatter` as a local hook, but replace floating `npx -y` with `npx --no-install`.
- Use `npx --no-install` for every npm-backed hook so hook execution never installs unpinned packages.
- Preserve the existing config file arguments:
    - `cspell --config cspell.json`
    - `markdownlint-cli2 --config .markdownlint-cli2.jsonc --fix`
- Preserve the non-JS hook repos and local lifecycle hooks:
    - `pre-commit/pre-commit-hooks`
    - `pre-commit/sync-pre-commit-deps`
    - `shellcheck-py/shellcheck-py`
    - `scop/pre-commit-shfmt`
    - `rhysd/actionlint`
    - `make lifecycle`
    - `make full-lifecycle`
    - `gitleaks/gitleaks`

### Update CI

Update `.github/workflows/ci.yml`:

- Keep the workflow name `CI`.
- Keep default workflow permissions read-only with `contents: read`.
- Trigger on:
    - `push` to `main`
    - `pull_request` to `main`
    - `workflow_dispatch`
    - a weekly schedule
- Use a non-hour-boundary cron, for example `17 8 * * 1`.
- Add workflow concurrency:
    - group: `ci-${{ github.workflow }}-${{ github.ref }}`
    - cancel in progress: `true`
- Keep the required job context stable:
    - job id: `lint`
    - job name: `lint`
- Add `timeout-minutes: 20`.
- Use `actions/setup-node` with:
    - `node-version: "lts/*"`
    - `cache: npm`
- Run `npm ci` before running `prek`.
- Run `prek` with `extra-args: --all-files`.

Add a scheduled-only failure reporting job:

- It should run only when `github.event_name == 'schedule'`.
- It should depend on `lint` and use `if: ${{ always() && github.event_name == 'schedule' }}`.
- It should use `permissions: contents: read, issues: write`.
- If scheduled `lint` fails, create or update an open issue titled `Scheduled CI failure detected` with label `ci-scheduled`.
- If scheduled `lint` succeeds and that issue exists, comment with the recovery run URL and close it.
- The issue body should include workflow name, run number, commit SHA, run URL, trigger time, and job result.

### Update Dependabot

Replace `.github/dependabot.yml` with daily grouped/cooldown configuration.

Required ecosystems:

- `github-actions`
- `docker`
- `pre-commit`
- `npm`

Do not add any other package ecosystem.

Use this behavior:

- Schedule all ecosystems daily.
- Use grouped updates with one group per ecosystem:
    - `github-actions`
    - `docker`
    - `pre-commit`
    - `npm-tooling`
- Use `open-pull-requests-limit: 5` for each ecosystem.
- Use `cooldown.default-days: 7` for each ecosystem.
- For `npm`, also use:
    - `semver-major-days: 30`
    - `semver-minor-days: 7`
    - `semver-patch-days: 3`
    - `versioning-strategy: increase`
- Use custom labels:
    - Always include `dependencies`.
    - Add exactly one ecosystem label: `github-actions`, `docker`, `pre-commit`, or `npm`.
- Use cleanup-specific commit-message prefixes:
    - `ci` for GitHub Actions updates.
    - `chore` for Docker, pre-commit, and npm tooling updates.

Delete `.github/workflows/pre-commit-autoupdate.yml`.

### Add Dependabot Auto-Merge Workflow

Add `.github/workflows/dependabot-auto-merge.yml`:

- Name: `Dependabot auto-merge`.
- Trigger on `pull_request` types:
    - `opened`
    - `reopened`
    - `synchronize`
- Permissions:
    - `contents: write`
    - `pull-requests: write`
- Add one job with:
    - `runs-on: ubuntu-latest`
    - `timeout-minutes: 5`
    - concurrency group: `dependabot-auto-merge-${{ github.event.pull_request.number }}`
    - cancel in progress: `true`
- Guard the job with both conditions:
    - `github.event.pull_request.user.login == 'dependabot[bot]'`
    - `github.repository == github.event.pull_request.head.repo.full_name`
- Fetch Dependabot metadata using `dependabot/fetch-metadata` pinned by full SHA with a version comment.
- Approve the PR:
    - `gh pr review --approve "$PR_URL"`
- Enable squash auto-merge:
    - `gh pr merge --auto --squash "$PR_URL"`
- Use `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` and `PR_URL: ${{ github.event.pull_request.html_url }}` for the `gh` steps.
- Do not filter out major updates. All Dependabot PRs may auto-merge when required checks pass.

### Apply GitHub Repository Settings

Before merging the workflow changes, apply these GitHub-side settings:

- Keep default workflow token permissions as read-only.
- Keep `can_approve_pull_request_reviews=true`.
- Create labels if they do not already exist:
    - `github-actions`
    - `docker`
    - `pre-commit`
    - `npm`
    - `ci-scheduled`
- Enable:
    - auto-merge
    - squash merge
    - update branch
    - delete branch on merge
- Disable:
    - merge commits
    - rebase merges
- Preserve the active default-branch ruleset's existing one-review PR rule.
- Preserve squash-only allowed merge methods.
- Add required status check `lint` from the GitHub Actions app.
- Use `strict_required_status_checks_policy=false`.

## Verification Checklist

After implementation, run these local checks:

```bash
npm ci
npx --no-install cspell --config cspell.json .
npx --no-install markdownlint-cli2 --config .markdownlint-cli2.jsonc "**/*.md" "#node_modules"
prek run --all-files
make lifecycle
git diff --check
```

Also verify:

- Workflow YAML is accepted by the existing `actionlint` hook.
- The `lint` check appears as a GitHub Actions check run on PRs.
- The active branch ruleset requires `lint`.
- A Dependabot PR receives the expected labels.
- The Dependabot auto-merge workflow approves the PR.
- GitHub queues squash auto-merge.
- The PR merges only after `lint` passes.
- A manually dispatched CI run completes successfully after the change lands.

## Assumptions and Defaults

- npm is the package manager.
- `package-lock.json` is committed.
- Node runtime uses `node-version: "lts/*"` for maximum self-maintenance.
- Scheduled CI is the alert path if a future Node LTS transition breaks tooling.
- Dependabot auto-merges all passing dependency updates, including major updates.
- `strict_required_status_checks_policy=false` is intentional to reduce Dependabot churn in this low-change repository.
- The npm manifest is private tooling metadata only, not an application package.
