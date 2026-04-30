# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Two cleanup scripts that remove local GitHub Copilot and VS Code chat session storage from VS Code Stable and VS Code Insiders — without uninstalling extensions or touching project files.

- `cleanup-vscode-copilot.sh` — macOS (bash), moves to `~/.Trash`
- `cleanup-vscode-copilot.ps1` — Windows (PowerShell 5.1+), moves to Recycle Bin with quarantine fallback

## Common commands

```bash
make build           # Build the Docker PSScriptAnalyzer lint image
make lint            # Build image if needed, then run PSScriptAnalyzer
make rebuild         # Rebuild image without cache
make clean           # Remove the local lint image
make lifecycle       # build + lint
make full-lifecycle  # clean + rebuild + lint
```

Lint a single file directly (image must be built first):

```bash
docker run --rm -v "$(pwd):/workspace" pssa-lint:latest /workspace/cleanup-vscode-copilot.ps1
```

## Architecture

Both scripts share the same behavioral contract:

1. **Dry-run by default** — print matching folders, move nothing.
2. **Target collection** — scan `workspaceStorage` for folders named `chatSessions`, `chatEditingSessions`, or matching `*copilot*` (case-insensitive). Optionally scan `globalStorage` with `--include-global` / `-IncludeGlobal`.
3. **Pruning** — when a collected path is nested inside another collected path, the child is dropped so the parent removal covers it. The PowerShell script implements this via `Get-PrunedTargets`.
4. **Deletion** — bash moves via `mv` into a timestamped `~/.Trash/vscode-copilot-cleanup-<timestamp>/` subtree. PowerShell uses `Microsoft.VisualBasic.FileIO.FileSystem` to send to Recycle Bin; falls back to a quarantine directory under `%LOCALAPPDATA%\vscode-copilot-cleanup\<timestamp>\` if Recycle Bin fails.

## Lint environment

`psscriptanalyzer.ps1` is the Docker entrypoint. It discovers `.ps1`/`.psm1`/`.psd1` files under `/workspace`, excludes common noise directories (`.git`, `node_modules`, etc.), runs `Invoke-ScriptAnalyzer`, and exits non-zero when diagnostics are found.

Analyzer rules are configured in `PSScriptAnalyzerSettings.psd1`. Three rules are excluded (`PSAvoidUsingWriteHost`, `PSUseSingularNouns`, `PSUseApprovedVerbs`) — see that file for rationale. Do not add them back without updating the rationale comments.

The Docker image uses PowerShell 7.5 on Ubuntu 24.04. If PSScriptAnalyzer complains about a minimum PowerShell version, run `make rebuild` to pull a fresh base image.
