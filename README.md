# VS Code Copilot Chat Storage Cleanup

Utilities for safely cleaning local GitHub Copilot and VS Code chat session storage from VS Code Stable and VS Code Insiders.

The repository also includes a Docker-based PowerShell lint environment so the Windows cleanup script can be checked from macOS or Linux without needing a Windows host for the purposes of CI.

|              |                                                                                                                                                                                                                                                                                                           |
|--------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Platform** | ![macOS](https://img.shields.io/badge/macOS-supported-brightgreen?logo=apple&logoColor=white) ![Windows](https://img.shields.io/badge/Windows-supported-brightgreen?logo=windows&logoColor=white) ![Linux](https://img.shields.io/badge/Linux-not_supported-lightgrey?logo=linux&logoColor=black)         |
| **Runtime**  | ![VS Code](https://img.shields.io/badge/VS_Code-Stable_%26_Insiders-007ACC?logo=visualstudiocode&logoColor=white) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white) ![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?logo=gnubash&logoColor=white) |
| **Lint**     | ![PSScriptAnalyzer](https://img.shields.io/badge/PSScriptAnalyzer-passing-brightgreen?logo=powershell&logoColor=white) ![Docker](https://img.shields.io/badge/lint-Docker_%2B_PowerShell_7.5-2496ED?logo=docker&logoColor=white)                                                                          |

## Purpose

> **Are you also done with Github Copilot after they decided to go to usage based billing? If so, this repo is for you!**

VS Code and extensions can keep per-workspace chat and extension state under `workspaceStorage`. Over time, Copilot Chat sessions and related local state can accumulate across many workspace hashes. This project provides cleanup scripts that target that local state without uninstalling VS Code extensions or deleting project files.

The cleanup scripts are designed to be conservative:

- Dry-run by default
- Support VS Code Stable and VS Code Insiders
- Remove known local Copilot and chat session storage
- Avoid removing installed extension packages
- Prefer reversible deletion behavior where practical

## Repository layout

```text
.
├── Dockerfile.psscriptanalyzer
├── PSScriptAnalyzerSettings.psd1
├── README.md
├── cleanup-vscode-copilot.ps1
├── cleanup-vscode-copilot.sh
├── cspell.json
├── makefile
└── psscriptanalyzer.ps1
```

## What gets cleaned

The scripts target these VS Code local storage folders:

```text
chatSessions
chatEditingSessions
*copilot*
```

For VS Code Stable:

```text
macOS:
~/Library/Application Support/Code/User/workspaceStorage

Windows:
%APPDATA%\Code\User\workspaceStorage
```

For VS Code Insiders:

```text
macOS:
~/Library/Application Support/Code - Insiders/User/workspaceStorage

Windows:
%APPDATA%\Code - Insiders\User\workspaceStorage
```

When the global cleanup option is enabled, the scripts also target Copilot-named folders in:

```text
macOS:
~/Library/Application Support/Code/User/globalStorage
~/Library/Application Support/Code - Insiders/User/globalStorage

Windows:
%APPDATA%\Code\User\globalStorage
%APPDATA%\Code - Insiders\User\globalStorage
```

## What does not get cleaned

The scripts intentionally do not remove installed VS Code extensions.

These locations are left alone:

```text
macOS:
~/.vscode/extensions
~/.vscode-insiders/extensions

Windows:
%USERPROFILE%\.vscode\extensions
%USERPROFILE%\.vscode-insiders\extensions
```

This means the cleanup resets local Copilot or chat state, but it does not uninstall GitHub Copilot, GitHub Copilot Chat, or any other VS Code extension.

## Safety model

### Default mode is dry run

Both cleanup scripts print the folders they would clean without moving or deleting anything.

### macOS cleanup uses Trash

The macOS script moves matching folders to:

```text
~/.Trash/vscode-copilot-cleanup-<timestamp>/
```

### Windows cleanup uses Recycle Bin

The Windows script attempts to move matching folders to the Recycle Bin.

If the Recycle Bin operation fails, it falls back to a quarantine directory:

```text
%LOCALAPPDATA%\vscode-copilot-cleanup\<timestamp>\
```

## Usage: macOS

Close VS Code and VS Code Insiders before running cleanup.

Make the script executable:

```bash
chmod +x cleanup-vscode-copilot.sh
```

Run a dry run:

```bash
./cleanup-vscode-copilot.sh
```

Clean workspace-level Copilot and chat session folders:

```bash
./cleanup-vscode-copilot.sh --delete
```

Also clean Copilot folders from `globalStorage`:

```bash
./cleanup-vscode-copilot.sh --delete --include-global
```

Show help:

```bash
./cleanup-vscode-copilot.sh --help
```

## Usage: Windows PowerShell

Close VS Code and VS Code Insiders before running cleanup.

Run a dry run:

```powershell
.\cleanup-vscode-copilot.ps1
```

Clean workspace-level Copilot and chat session folders:

```powershell
.\cleanup-vscode-copilot.ps1 -Delete
```

Also clean Copilot folders from `globalStorage`:

```powershell
.\cleanup-vscode-copilot.ps1 -Delete -IncludeGlobal
```

If script execution is blocked for the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Then rerun the script.

## Recommended cleanup sequence

Start with a dry run:

```bash
./cleanup-vscode-copilot.sh
```

or on Windows:

```powershell
.\cleanup-vscode-copilot.ps1
```

Review the matching folders.

Then run workspace cleanup:

```bash
./cleanup-vscode-copilot.sh --delete
```

or on Windows:

```powershell
.\cleanup-vscode-copilot.ps1 -Delete
```

Open VS Code and confirm old Copilot or chat sessions are gone.

Only use global cleanup if stale Copilot state still appears:

```bash
./cleanup-vscode-copilot.sh --delete --include-global
```

or on Windows:

```powershell
.\cleanup-vscode-copilot.ps1 -Delete -IncludeGlobal
```

## Notes about other agents

VS Code can display chat sessions from more than one provider. Removing Copilot and VS Code chat session storage does not necessarily remove history owned by other tools.

For example, Claude Code keeps its own local history under:

```text
~/.claude/
```

Common Claude Code history locations include:

```text
~/.claude/projects/
~/.claude/history.jsonl
~/.claude/file-history/
```

Those paths are outside the scope of these scripts.

## Linting PowerShell without Windows

This repository includes a Docker-based PSScriptAnalyzer environment. It lets macOS or Linux users lint the PowerShell script without a Windows system.

The Docker image uses:

- PowerShell 7.5 on Ubuntu 24.04
- Latest available `PSScriptAnalyzer` from PSGallery at image build time
- Repository-mounted lint execution

## Build the lint image

```bash
make build
```

Or directly:

```bash
docker build --pull \
  -f Dockerfile.psscriptanalyzer \
  -t pssa-lint:latest \
  .
```

## Rebuild without cache

```bash
make rebuild
```

Or directly:

```bash
docker build --pull --no-cache \
  -f Dockerfile.psscriptanalyzer \
  -t pssa-lint:latest \
  .
```

## Run lint

```bash
make lint
```

Or directly:

```bash
docker run --rm \
  -v "$(pwd):/workspace" \
  pssa-lint:latest
```

## Run lint against a single file

```bash
docker run --rm \
  -v "$(pwd):/workspace" \
  pssa-lint:latest \
  /workspace/cleanup-vscode-copilot.ps1
```

## PSScriptAnalyzer settings

The analyzer settings are defined in:

```text
PSScriptAnalyzerSettings.psd1
```

The current configuration keeps useful formatting and maintainability checks enabled while suppressing rules that are noisy for this repository's utility-script style.

Excluded rules:

```text
PSAvoidUsingWriteHost
PSUseSingularNouns
PSUseApprovedVerbs
```

Rationale:

- `Write-Host` is acceptable here because these scripts are interactive cleanup utilities with human-facing dry-run and status output.
- Some helper function names are clearer in plural form, such as functions that return collections.
- Approved verb enforcement is useful for modules, but too noisy for small standalone cleanup utilities.

Enabled formatting and quality rules include:

```text
PSAvoidUsingCmdletAliases
PSUseConsistentIndentation
PSUseConsistentWhitespace
PSPlaceOpenBrace
PSPlaceCloseBrace
PSAlignAssignmentStatement
```

## Make targets

```text
make build
```

Builds the lint image.

```text
make rebuild
```

Rebuilds the lint image with `--no-cache`.

```text
make lint
```

Builds the lint image if needed and runs PSScriptAnalyzer against the repository.

```text
make clean
```

Removes the local lint image.

## Docker build context

The repository should include a `.dockerignore` that uses an allowlist-style build context. The lint image only needs the Dockerfile and lint entrypoint at build time.

Recommended `.dockerignore`:

```dockerignore
# Ignore everything by default.
**

# Keep Dockerfile and analyzer entrypoint.
!Dockerfile.psscriptanalyzer
!psscriptanalyzer.ps1

# Keep analyzer settings.
!PSScriptAnalyzerSettings.psd1

# Optional repo metadata/config.
!README.md
!cspell.json
!makefile

# Keep scripts for validation and examples.
!cleanup-vscode-copilot.ps1
!cleanup-vscode-copilot.sh

# Always exclude Git and local/editor noise.
.git
.gitignore
.github
.vscode
.idea
.DS_Store
*.swp
*.swo

# Exclude runtime/build artifacts.
tmp
temp
.cache
coverage
dist
build
bin
obj
```

## Verifying the lint image

Check the PowerShell version:

```bash
docker run --rm \
  --entrypoint pwsh \
  pssa-lint:latest \
  -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion'
```

Check the installed PSScriptAnalyzer version:

```bash
docker run --rm \
  --entrypoint pwsh \
  pssa-lint:latest \
  -NoLogo -NoProfile -Command 'Import-Module PSScriptAnalyzer; Get-Module PSScriptAnalyzer'
```

## Expected lint output

A successful run should end with:

```text
PSScriptAnalyzer passed. No diagnostics found.
```

If findings are present, the wrapper prints diagnostics in this format:

```text
<file>:<line>:<column>: <severity>: <rule>: <message>
```

The container exits non-zero when diagnostics are found, which makes it suitable for CI.

## CI example

Example GitHub Actions workflow:

```yaml
name: lint

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  psscriptanalyzer:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build lint image
        run: docker build --pull -f Dockerfile.psscriptanalyzer -t pssa-lint:latest .

      - name: Run PSScriptAnalyzer
        run: docker run --rm -v "$PWD:/workspace" pssa-lint:latest
```

## Troubleshooting

### `PSScriptAnalyzer` requires a newer PowerShell version

If you see an error similar to this:

```text
Minimum supported version of PSScriptAnalyzer for PowerShell Core is 7.4.6
```

Rebuild the image without cache:

```bash
make rebuild
```

The Dockerfile pins the base image to PowerShell 7.5 on Ubuntu 24.04 to avoid old `latest` image drift.

### Docker still appears to use an old image

Remove the local image and rebuild:

```bash
make clean
make rebuild
```

Or directly:

```bash
docker image rm pssa-lint:latest
docker build --pull --no-cache \
  -f Dockerfile.psscriptanalyzer \
  -t pssa-lint:latest \
  .
```

### Cleanup script finds nothing

That usually means there are no matching local Copilot or chat session folders left in the known VS Code storage paths.

You can manually inspect workspace storage on macOS:

```bash
find "$HOME/Library/Application Support/Code/User/workspaceStorage" \
  \( -name "chatSessions" -o -name "chatEditingSessions" -o -iname "*copilot*" \) \
  -type d \
  -print 2>/dev/null
```

For VS Code Insiders:

```bash
find "$HOME/Library/Application Support/Code - Insiders/User/workspaceStorage" \
  \( -name "chatSessions" -o -name "chatEditingSessions" -o -iname "*copilot*" \) \
  -type d \
  -print 2>/dev/null
```

## Caveats

These scripts clean local VS Code state. They do not control or delete:

- GitHub account-level Copilot data
- GitHub service-side data
- Claude Code local history under `~/.claude`
- Other AI extension histories stored outside VS Code `workspaceStorage`
- Installed VS Code extension packages

Use dry-run output before deletion and close VS Code before cleanup.
