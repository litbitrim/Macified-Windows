#Requires -Version 5.1
<#
    Applies the look settings from macified.psd1.

    Safety rules:
      * dry run by default; writes only with -Apply
      * HKCU only, no HKLM, no system files, no theme patching
      * every value is backed up before the first write
      * values marked Protected are never forced; they are reported as manual
      * no downloads, no process starts, no app installation

    Exit codes: 0 = everything written, 2 = manual/failed values remain.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$BackupDirectory = (Join-Path $env:LOCALAPPDATA 'MacifiedWindows\backups'),
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $scriptDirectory '..\config\macified.psd1'
}

Import-Module (Join-Path $scriptDirectory 'Macified.Core.psm1') -Force
$config = Get-MacifiedConfig -Path $ConfigPath

# Refuse any configuration that would leave the per-user hive.
foreach ($setting in $config.Look.Settings) {
    if ($setting.Path -notmatch '^Software\\' -or $setting.Path -match '^Software\\Microsoft\\Windows\\CurrentVersion\\Policies') {
        throw "Refusing non-user-scoped or policy path: $($setting.Path)"
    }
}

$plan = New-Object System.Collections.ArrayList

foreach ($setting in $config.Look.Settings) {
    $key = "HKCU:\$($setting.Path)"
    $exists = Test-Path -LiteralPath $key
    $current = $null
    $currentExists = $false

    if ($exists) {
        $item = Get-ItemProperty -LiteralPath $key -Name $setting.Name -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            $current = $item.($setting.Name)
            $currentExists = $true
        }
    }

    $comparison = Compare-MacifiedSetting -Setting $setting -Actual $current -ValueMissing (-not $currentExists)
    $isProtected = ($setting.ContainsKey('Protected') -and [bool]$setting.Protected)

    [void]$plan.Add([pscustomobject]@{
        Id             = $setting.Id
        Label          = $setting.Label
        Key            = "HKCU:\$($setting.Path)"
        Name           = $setting.Name
        Kind           = $setting.Kind
        Expected       = $setting.Expected
        Current        = $(if ($currentExists) { $current } elseif ($comparison.UsedDefault) { [string]$comparison.Actual + ' (default)' } else { '<missing>' })
        CurrentRaw     = $current
        CurrentSet     = $currentExists
        NeedsChange    = ($comparison.Status -eq 'FAIL')
        Protected      = $isProtected
        ProtectionNote = $(if ($setting.ContainsKey('ProtectionNote')) { $setting.ProtectionNote } else { '' })
    })
}

Write-Host ''
Write-Host 'Macified Windows - look baseline plan (HKCU only)' -ForegroundColor Cyan
Write-Host ''
foreach ($item in $plan) {
    $marker = if (-not $item.NeedsChange) { 'ok    ' } elseif ($item.Protected) { 'MANUAL' } else { 'CHANGE' }
    Write-Host ('{0}  {1,-30} {2,-20} -> {3}' -f $marker, $item.Label, [string]$item.Current, [string]$item.Expected)
}
Write-Host ''

$pending = @($plan | Where-Object { $_.NeedsChange })
$writable = @($pending | Where-Object { -not $_.Protected })
$protected = @($pending | Where-Object { $_.Protected })

if (-not $Apply) {
    Write-Host ('DRY RUN: {0} value(s) would be written, {1} protected/manual. Re-run with -Apply.' -f $writable.Count, $protected.Count) -ForegroundColor Yellow
    Write-Host 'No registry value was modified.' -ForegroundColor Yellow
    exit 0
}

if ($writable.Count -eq 0 -and $protected.Count -eq 0) {
    Write-Host 'Nothing to do: all values already match.' -ForegroundColor Green
    exit 0
}

$failed = @()

if ($writable.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $BackupDirectory)) {
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    }

    $backupPath = Join-Path $BackupDirectory ('look-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $backup = [pscustomobject]@{
        CreatedAt = (Get-Date).ToString('s')
        Tool      = 'macified-windows/Apply-MacifiedLook'
        OsBuild   = [string](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
        Items     = @($plan | ForEach-Object {
            [pscustomobject]@{
                Id      = $_.Id
                Path    = $_.Key
                Name    = $_.Name
                Kind    = $_.Kind
                Existed = $_.CurrentSet
                Value   = $_.CurrentRaw
            }
        })
    }

    $backup | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $backupPath -Encoding UTF8

    foreach ($item in $writable) {
        try {
            $key = $item.Key
            if (-not (Test-Path -LiteralPath $key)) {
                New-Item -Path $key -Force | Out-Null
            }

            if ($item.Kind -eq 'DWord') {
                Set-ItemProperty -LiteralPath $key -Name $item.Name -Value ([int]$item.Expected) -Type DWord
            }
            else {
                Set-ItemProperty -LiteralPath $key -Name $item.Name -Value ([string]$item.Expected) -Type String
            }

            Write-Host ('WROTE  {0}' -f $item.Label) -ForegroundColor Green
        }
        catch {
            $failed += $item
            Write-Host ('FAILED {0}: {1}' -f $item.Label, $_.Exception.Message) -ForegroundColor Red
        }
    }

    $statePath = Join-Path (Split-Path -Parent $BackupDirectory) 'last-apply.json'
    [pscustomobject]@{
        AppliedAt  = (Get-Date).ToString('s')
        BackupPath = $backupPath
        Values     = ($writable.Count - $failed.Count)
    } | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8

    Write-Host ('Backup: {0}' -f $backupPath) -ForegroundColor Yellow
}

foreach ($item in $protected) {
    Write-Host ('MANUAL {0}: OS-protected, not written. {1}' -f $item.Label, $item.ProtectionNote) -ForegroundColor Yellow
}

Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host ('{0} value(s) could not be written.' -f $failed.Count) -ForegroundColor Red
    exit 2
}
if ($protected.Count -gt 0) {
    Write-Host ('{0} value(s) require a manual/OS-supported path.' -f $protected.Count) -ForegroundColor Yellow
    exit 2
}

Write-Host 'All requested values applied.' -ForegroundColor Green
Write-Host 'Sign out and back in if the taskbar does not refresh immediately.' -ForegroundColor Yellow
exit 0
