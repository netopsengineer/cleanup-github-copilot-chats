@{
    Severity = @(
        'Error',
        'Warning'
    )

    ExcludeRules = @(
        # Utility scripts intentionally write human-facing console output.
        'PSAvoidUsingWriteHost',

        # Internal helper names like Get-VsCodeUserRoots are clearer as plural.
        'PSUseSingularNouns',

        # This is often counterproductive for small utility scripts.
        # Remove this exclusion if you want approved verb enforcement.
        'PSUseApprovedVerbs'
    )

    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            AllowList = @()
        }

        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckPipeForRedundantWhitespace = $true
            CheckSeparator = $true
        }

        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }

        PSAlignAssignmentStatement = @{
            Enable = $false
            CheckHashtable = $false
        }
    }
}
