#Requires -Version 7.0

<#
.SYNOPSIS
    Runs PSScriptAnalyzer against a mounted repository.

.DESCRIPTION
    This script is intended to run inside a Linux PowerShell container.

    It discovers PowerShell source files, runs Invoke-ScriptAnalyzer, prints
    diagnostics, and exits non-zero when analyzer findings are present.

.PARAMETER Path
    Repository or file path to analyze.

.PARAMETER Settings
    Optional PSScriptAnalyzer settings file.

.PARAMETER Severity
    Analyzer severities to include.

.PARAMETER NoSummary
    Suppress the per-severity and per-rule summary printed after diagnostics.

.EXAMPLE
    docker run --rm -v "$PWD:/workspace" pssa-lint

.EXAMPLE
    docker run --rm -v "$PWD:/workspace" pssa-lint /workspace -Settings /workspace/PSScriptAnalyzerSettings.psd1
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Path = "/workspace",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Settings = "/workspace/PSScriptAnalyzerSettings.psd1",

    [Parameter()]
    [ValidateSet("Error", "Warning", "Information", "ParseError")]
    [string[]]$Severity = @("Error", "Warning"),

    [Parameter()]
    [switch]$NoSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-AnalyzerHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath,

        [Parameter(Mandatory)]
        [string]$SettingsPath
    )

    $module = Get-Module -ListAvailable -Name PSScriptAnalyzer |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
    Write-Host "PSScriptAnalyzer version: $($module.Version)"
    Write-Host "Target path: $TargetPath"

    if (Test-Path -LiteralPath $SettingsPath) {
        Write-Host "Settings file: $SettingsPath"
    }
    else {
        Write-Host "Settings file: <not found, using default analyzer settings>"
    }

    Write-Host ""
}

function Test-ExcludedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    $excludedDirectories = @(
        ".git",
        ".github",
        ".vscode",
        ".idea",
        "node_modules",
        "vendor",
        "bin",
        "obj"
    )

    $pathParts = $LiteralPath -split [regex]::Escape(
        [System.IO.Path]::DirectorySeparatorChar
    )

    foreach ($pathPart in $pathParts) {
        if ($pathPart -in $excludedDirectories) {
            return $true
        }
    }

    return $false
}

function Get-PowerShellSourceFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    $validExtensions = @(".ps1", ".psm1", ".psd1")

    if (Test-Path -LiteralPath $LiteralPath -PathType Leaf) {
        $item = Get-Item -LiteralPath $LiteralPath

        if ($item.Extension -in $validExtensions) {
            return @($item)
        }

        return @()
    }

    Get-ChildItem -LiteralPath $LiteralPath -Recurse -File -Force |
        Where-Object {
            $_.Extension -in $validExtensions -and
            -not (Test-ExcludedPath -LiteralPath $_.FullName)
        }
}

function Format-AnalyzerDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Diagnostic
    )

    process {
        $scriptName = if ($Diagnostic.ScriptName) {
            $Diagnostic.ScriptName
        }
        else {
            "<unknown>"
        }

        $line = if ($null -ne $Diagnostic.Line) {
            $Diagnostic.Line
        }
        else {
            0
        }

        $column = if ($null -ne $Diagnostic.Column) {
            $Diagnostic.Column
        }
        else {
            0
        }

        "{0}:{1}:{2}: {3}: {4}: {5}" -f @(
            $scriptName,
            $line,
            $column,
            $Diagnostic.Severity,
            $Diagnostic.RuleName,
            $Diagnostic.Message
        )
    }
}

Write-AnalyzerHeader -TargetPath $Path -SettingsPath $Settings

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "Path does not exist: $Path"
    exit 2
}

$sourceFiles = @(Get-PowerShellSourceFile -LiteralPath $Path)

if ($sourceFiles.Count -eq 0) {
    Write-Host "No PowerShell files found."
    exit 0
}

Write-Host "PowerShell files discovered: $($sourceFiles.Count)"
Write-Host ""

$settingsAvailable = Test-Path -LiteralPath $Settings

$diagnostics = @(
    $sourceFiles | ForEach-Object {
        $fileParams = @{
            Path = $_.FullName
            Severity = $Severity
        }
        if ($settingsAvailable) {
            $fileParams.Settings = $Settings
        }
        Invoke-ScriptAnalyzer @fileParams
    }
)

if ($diagnostics.Count -eq 0) {
    Write-Host "PSScriptAnalyzer passed. No diagnostics found."
    exit 0
}

$diagnostics |
    Sort-Object -Property ScriptName, Line, Column, RuleName |
    Format-AnalyzerDiagnostic |
    ForEach-Object {
        Write-Host $_
    }

if (-not $NoSummary) {
    Write-Host ""
    Write-Host "Summary by severity:"

    $diagnostics |
        Group-Object -Property Severity |
        Sort-Object -Property Name |
        ForEach-Object {
            Write-Host ("  {0}: {1}" -f $_.Name, $_.Count)
        }

    Write-Host ""
    Write-Host "Summary by rule:"

    $ruleSortProperties = @(
        @{
            Expression = "Count"
            Descending = $true
        },
        @{
            Expression = "Name"
            Ascending = $true
        }
    )

    $diagnostics |
        Group-Object -Property RuleName |
        Sort-Object -Property $ruleSortProperties |
        ForEach-Object {
            Write-Host ("  {0}: {1}" -f $_.Name, $_.Count)
        }
}

exit 1
