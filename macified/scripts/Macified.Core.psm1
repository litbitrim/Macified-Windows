#Requires -Version 5.1
<#
    Macified.Core
    Pure, side-effect-free helpers shared by the verifier, the apply/undo scripts
    and the Pester suite. Nothing in this module writes to the registry, starts
    processes or downloads files.
#>

function Get-MacifiedConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    return Import-PowerShellDataFile -LiteralPath $resolved
}

function Convert-MacHexToDword {
    <#
        Converts '#RRGGBB' to the ABGR DWORD layout used by Windows (AccentColor).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Hex
    )

    if ($Hex -notmatch '^#?([0-9A-Fa-f]{6})$') {
        throw "Invalid hex color: $Hex"
    }

    $rgb = $Matches[1]
    $r = [Convert]::ToInt32($rgb.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($rgb.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($rgb.Substring(4, 2), 16)

    $abgr = '{0:X2}{1:X2}{2:X2}{3:X2}' -f 255, $b, $g, $r
    return [Convert]::ToUInt32($abgr, 16)
}

function Convert-MacDwordToHex {
    <#
        Converts a stored ABGR DWORD back to '#RRGGBB'. Accepts negative Int32
        values because the registry returns them for colours above 0x7FFFFFFF.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int64]$Value
    )

    $masked = $Value -band 0xFFFFFFFFL
    $hex = '{0:X8}' -f $masked
    return '#' + $hex.Substring(6, 2) + $hex.Substring(4, 2) + $hex.Substring(2, 2)
}

function Compare-MacifiedSetting {
    <#
        Compares one desired-state entry against an observed registry value.
        Returns PASS/FAIL plus a machine-readable reason.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Setting,

        [Parameter(Mandatory = $false)]
        $Actual,

        [bool]$ValueMissing = $false
    )

    $usedDefault = $false
    if ($ValueMissing -or $null -eq $Actual) {
        # A missing HKCU value means the Windows default is in effect. Compare
        # against that documented default instead of reporting false drift.
        if ($Setting.ContainsKey('Default')) {
            $Actual = $Setting.Default
            $usedDefault = $true
        }
        else {
            return [pscustomobject]@{
                Id          = $Setting.Id
                Status      = 'FAIL'
                Expected    = $Setting.Expected
                Actual      = $null
                Reason      = 'value-missing'
                UsedDefault = $false
            }
        }
    }

    if ([string]$Setting.Kind -eq 'DWord') {
        $isMatch = ([int64]$Actual -eq [int64]$Setting.Expected)
    }
    else {
        $isMatch = ([string]$Actual -eq [string]$Setting.Expected)
    }

    return [pscustomobject]@{
        Id          = $Setting.Id
        Status      = $(if ($isMatch) { 'PASS' } else { 'FAIL' })
        Expected    = $Setting.Expected
        Actual      = $Actual
        Reason      = $(if ($isMatch) { 'match' } else { 'drift' })
        UsedDefault = $usedDefault
    }
}

function Get-MacifiedAirPodsGate {
    <#
        Hardware gate for the AirPods live test. A paired device alone is not
        enough: without a Bluetooth audio endpoint no A2DP/HFP test is possible.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$PairedAirPods,

        [Parameter(Mandatory = $true)]
        [bool]$BluetoothAudioEndpoint
    )

    $reasons = @()
    $status = 'PASS'

    if (-not $PairedAirPods) {
        $reasons += 'no paired AirPods device'
        $status = 'FAIL'
    }
    elseif (-not $BluetoothAudioEndpoint) {
        # Paired but asleep/in the case: testable after connecting, not a defect.
        $reasons += 'AirPods paired but no active audio endpoint (connect them to test)'
        $status = 'WARN'
    }

    return [pscustomobject]@{
        Status  = $status
        Gate    = 'AirPods live test'
        Reasons = $reasons
    }
}

function Get-MacifiedRepoHygiene {
    <#
        Fails when binary or proprietary artefacts are tracked in the fork.
        This is the guard against re-adding upstream packages.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string[]]$ForbiddenExtensions
    )

    $rootPath = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
    $normalized = @($ForbiddenExtensions | ForEach-Object { $_.ToLowerInvariant() })

    $files = @(Get-ChildItem -LiteralPath $rootPath -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\\.git\\' -and
            $_.FullName -notmatch '\\\.freebuff\\' -and
            $_.FullName -notmatch '\\\.artifacts\\'
        })

    $hits = @()
    foreach ($file in $files) {
        if ($normalized -contains $file.Extension.ToLowerInvariant()) {
            $relative = $file.FullName.Substring($rootPath.Length).TrimStart([char[]]@('\', '/'))
            $hits += $relative
        }
    }

    return [pscustomobject]@{
        Status  = $(if ($hits.Count -eq 0) { 'PASS' } else { 'FAIL' })
        Checked = $files.Count
        Files   = $hits
    }
}

Export-ModuleMember -Function @(
    'Get-MacifiedConfig'
    'Convert-MacHexToDword'
    'Convert-MacDwordToHex'
    'Compare-MacifiedSetting'
    'Get-MacifiedAirPodsGate'
    'Get-MacifiedRepoHygiene'
)
