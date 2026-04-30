#Requires -Version 5.1

<#
.SYNOPSIS
  Safely cleans VS Code and VS Code Insiders Copilot/chat workspace storage on Windows.

.DESCRIPTION
  Dry-run by default.

  Targets:
    - %APPDATA%\Code\User\workspaceStorage
    - %APPDATA%\Code - Insiders\User\workspaceStorage

  Removes matching workspace folders:
    - chatSessions
    - chatEditingSessions
    - *copilot*

  Optional:
    - Include Copilot folders under globalStorage with -IncludeGlobal

  Does not remove installed extensions:
    - $HOME\.vscode\extensions
    - $HOME\.vscode-insiders\extensions

.PARAMETER Delete
  Perform the move. Without this switch the script runs in dry-run mode and
  only lists matching folders.

.PARAMETER IncludeGlobal
  Also scan globalStorage for Copilot folders in addition to workspaceStorage.

.EXAMPLE
  .\cleanup-vscode-copilot.ps1

.EXAMPLE
  .\cleanup-vscode-copilot.ps1 -Delete

.EXAMPLE
  .\cleanup-vscode-copilot.ps1 -Delete -IncludeGlobal
#>

[CmdletBinding()]
param(
    [switch]$Delete,
    [switch]$IncludeGlobal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($env:OS -ne "Windows_NT") {
    throw "This script is intended for Windows."
}

$DryRun = -not $Delete
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$QuarantineRoot = Join-Path $env:LOCALAPPDATA "vscode-copilot-cleanup\$Timestamp"

# Load Microsoft.VisualBasic once at startup. On PowerShell 7 the assembly is
# available via the .NET compatibility layer on Windows, but not guaranteed on
# all configurations. When unavailable, Move-ToRecycleBin skips the VB path and
# goes directly to quarantine.
$RecycleBinAvailable = $false
try {
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
    $RecycleBinAvailable = $true
}
catch {
    Write-Warning "Microsoft.VisualBasic assembly not available; items will move to quarantine instead of the Recycle Bin."
    Write-Warning "Quarantine location: $QuarantineRoot"
}

$TargetSet = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)

function Add-Target {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $ResolvedPath = (Resolve-Path -LiteralPath $Path).Path
    [void]$script:TargetSet.Add($ResolvedPath)
}

function Get-VsCodeUserRoots {
    @(
        [PSCustomObject]@{
            Name = "VS Code"
            Path = Join-Path $env:APPDATA "Code\User"
        },
        [PSCustomObject]@{
            Name = "VS Code Insiders"
            Path = Join-Path $env:APPDATA "Code - Insiders\User"
        }
    )
}

function Collect-WorkspaceTargets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserRoot
    )

    $WorkspaceStorage = Join-Path $UserRoot "workspaceStorage"

    if (-not (Test-Path -LiteralPath $WorkspaceStorage -PathType Container)) {
        return
    }

    Get-ChildItem -LiteralPath $WorkspaceStorage -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -in @("chatSessions", "chatEditingSessions") -or
            $_.Name -like "*copilot*"
        } |
        ForEach-Object {
            Add-Target -Path $_.FullName
        }
}

function Collect-GlobalTargets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserRoot
    )

    $GlobalStorage = Join-Path $UserRoot "globalStorage"

    if (-not (Test-Path -LiteralPath $GlobalStorage -PathType Container)) {
        return
    }

    Get-ChildItem -LiteralPath $GlobalStorage -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "*copilot*"
        } |
        ForEach-Object {
            Add-Target -Path $_.FullName
        }
}

function Get-PrunedTargets {
    $Selected = New-Object "System.Collections.Generic.List[string]"

    foreach ($Target in ($script:TargetSet | Sort-Object { $_.Length })) {
        $NestedUnderExistingTarget = $false

        foreach ($ExistingTarget in $Selected) {
            $ExistingPrefix = $ExistingTarget.TrimEnd("\") + "\"

            if ($Target.StartsWith($ExistingPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $NestedUnderExistingTarget = $true
                break
            }
        }

        if (-not $NestedUnderExistingTarget) {
            [void]$Selected.Add($Target)
        }
    }

    return $Selected
}

function Move-ToQuarantine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    $Item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    $Root = [System.IO.Path]::GetPathRoot($Item.FullName)
    $DriveName = $Item.PSDrive.Name -replace "[^\w.-]", "_"
    $RelativePath = $Item.FullName.Substring($Root.Length)

    $Destination = Join-Path $script:QuarantineRoot (Join-Path $DriveName $RelativePath)
    $DestinationParent = Split-Path -Parent $Destination

    New-Item -ItemType Directory -Path $DestinationParent -Force | Out-Null
    Move-Item -LiteralPath $Item.FullName -Destination $Destination -Force
}

function Move-ToRecycleBin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    $Item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop

    if ($script:RecycleBinAvailable) {
        try {
            if ($Item.PSIsContainer) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                    $Item.FullName,
                    [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
                )
            }
            else {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                    $Item.FullName,
                    [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
                )
            }
            return
        }
        catch {
            Write-Warning "Recycle Bin move failed for: $($Item.FullName)"
            Write-Warning "Falling back to quarantine folder: $script:QuarantineRoot"
        }
    }

    Move-ToQuarantine -LiteralPath $Item.FullName
}

Write-Host "Checking VS Code and VS Code Insiders Copilot/chat storage..."
Write-Host ""

foreach ($Root in Get-VsCodeUserRoots) {
    Write-Host "Scanning workspaceStorage for $($Root.Name): $($Root.Path)"
    Collect-WorkspaceTargets -UserRoot $Root.Path

    if ($IncludeGlobal) {
        Write-Host "Scanning globalStorage for $($Root.Name): $($Root.Path)"
        Collect-GlobalTargets -UserRoot $Root.Path
    }
}

$Targets = @(Get-PrunedTargets)

if ($Targets.Count -eq 0) {
    Write-Host ""
    Write-Host "No matching Copilot or chat session folders found."
    exit 0
}

Write-Host ""
Write-Host "Matching folders:"
$Targets | ForEach-Object {
    Write-Host "  $_"
}

Write-Host ""

if ($DryRun) {
    Write-Host "Dry run only. Nothing was moved."
    Write-Host ""
    Write-Host "To move these folders to the Recycle Bin:"
    Write-Host "  .\cleanup-vscode-copilot.ps1 -Delete"
    Write-Host ""
    Write-Host "To also include Copilot folders from globalStorage:"
    Write-Host "  .\cleanup-vscode-copilot.ps1 -Delete -IncludeGlobal"
    exit 0
}

Write-Host "Moving matching folders to the Recycle Bin."
Write-Host "Fallback quarantine location:"
Write-Host "  $QuarantineRoot"
Write-Host ""

$ErrorCount = 0

foreach ($Target in $Targets) {
    if (Test-Path -LiteralPath $Target) {
        Write-Host "Moving: $Target"
        try {
            Move-ToRecycleBin -LiteralPath $Target
        }
        catch {
            Write-Warning "Failed to move '$Target': $_"
            $ErrorCount++
        }
    }
}

Write-Host ""

if ($ErrorCount -gt 0) {
    Write-Warning "$ErrorCount item(s) could not be moved. Check warnings above."
    exit 1
}

Write-Host "Done."
