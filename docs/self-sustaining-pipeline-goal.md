# Goal Prompt for Self-Sustaining Pipeline Implementation

Use this file as the `/goal` objective text. Reference it together with `@docs/self-sustaining-pipeline-plan.md`.

## Suggested Command

```text
/goal Implement the self-sustaining dependency and quality pipeline described in @docs/self-sustaining-pipeline-plan.md. Treat that plan file as the source of truth. Work end to end: update the repository files, apply the required GitHub repository settings and ruleset changes, verify locally, inspect GitHub-side state, and keep going until the pipeline is ready for Dependabot PRs to self-test and auto-merge safely.
```

## Implementation Instructions for the Agent

Treat `@docs/self-sustaining-pipeline-plan.md` as authoritative. Do not substitute a different automation strategy without explicit user approval.

Implement the plan end to end:

- Add locked npm tooling with exact dev dependency versions and a committed lockfile.
- Convert JS-based pre-commit hooks to local npm-backed hooks using `npx --no-install`.
- Update CI to install npm tooling, run locked hooks, run weekly scheduled health checks, and report scheduled failures as GitHub issues.
- Replace the weekly Dependabot config with daily grouped/cooldown ecosystems for GitHub Actions, Docker, pre-commit, and npm.
- Remove the old pre-commit autoupdate workflow.
- Add the approval-capable Dependabot auto-merge workflow.
- Apply the GitHub repository merge settings, labels, Actions permissions, and ruleset requirements described in the plan.

## Success Criteria

The work is complete only when all of the following are true:

- `npm ci` succeeds from a clean checkout state.
- `prek run --all-files` succeeds.
- `make lifecycle` succeeds or any failure is fully diagnosed and documented.
- GitHub Actions workflow syntax passes the repo's `actionlint` hook.
- The active default-branch ruleset requires the `lint` check.
- The repository allows only squash merges at both the ruleset and repo merge-settings levels.
- GitHub Actions default token permissions remain read-only.
- GitHub Actions can approve pull request reviews.
- Dependabot PRs can be approved and queued for squash auto-merge by the new workflow.
- The final response reports every file changed, every GitHub setting changed, and every verification command result.

## Operating Pattern

Use an agentic implementation loop:

- Read the plan file first and restate the intended changes briefly.
- Inspect current repo and GitHub settings before editing.
- Make narrowly scoped changes.
- Run local verification.
- Fix any failures caused by the changes.
- Apply and re-read GitHub-side settings.
- If a network, auth, or permission issue blocks a GitHub-side operation, stop and report the exact missing permission or command needed.
- Do not leave the repository in a partially migrated state if a local verification failure can be fixed within the same run.

## Constraints

- Do not add application code.
- Do not introduce pnpm, yarn, or a Node runtime package surface beyond private repository tooling.
- Do not weaken branch protections or bypass required checks.
- Do not remove the one-review requirement.
- Do not use broad destructive git commands.
- Preserve unrelated user changes if the worktree is dirty.
