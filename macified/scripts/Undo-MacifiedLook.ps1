#Requires -Version 5.1
<#
    Restores the most recent (or an explicit) look baseline backup.
    Dry run by default; writes only with -Apply.
#>
[CmdletBinding()]
param(
    [string]$BackupPath,
    [string]$ConfigPath,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$stateDirectory = Join-Path $env:LOCALAPPDATA 'MacifiedWindows'
$statePath = Join-Path $stateDirectory 'last-apply.json'
$state = $null
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    if ($null -ne $state -and -not [string]::IsNullOrWhiteSpace([string]$state.BackupPath)) {
        $BackupPath = $state.BackupPath
    }
    else {
        # A failed/partial apply may not have written last-apply.json.
        $backupDirectory = Join-Path $stateDirectory 'backups'
        $latest = Get-ChildItem -LiteralPath $backupDirectory -Filter 'look-*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($null -eq $latest) {
            throw 'No backup found. Pass -BackupPath explicitly.'
        }

        $BackupPath = $latest.FullName
    }
}

$resolvedBackup = (Resolve-Path -LiteralPath $BackupPath -ErrorAction Stop).Path
$expectedConfigSha256 = $null
$stateBackupPath = $null
if ($null -ne $state -and -not [string]::IsNullOrWhiteSpace([string]$state.BackupPath)) {
    try {
        $stateBackupPath = (Resolve-Path -LiteralPath $state.BackupPath -ErrorAction Stop).Path
    }
    catch {
        $stateBackupPath = $null
    }
}
$matchesLastApply = ($null -ne $stateBackupPath -and $stateBackupPath -eq $resolvedBackup)
$hasBackupDigest = $matchesLastApply -and -not [string]::IsNullOrWhiteSpace([string]$state.BackupSha256)
$hasConfigDigest = $matchesLastApply -and -not [string]::IsNullOrWhiteSpace([string]$state.ConfigSha256)
if (-not $hasBackupDigest -or -not $hasConfigDigest) {
    Write-Warning 'No saved SHA-256 digest covers this backup/config; configured paths and value types will still be validated.'
}
if ($hasBackupDigest) {
    $actualBackupSha256 = (Get-FileHash -LiteralPath $resolvedBackup -Algorithm SHA256).Hash
    if ($actualBackupSha256 -ne [string]$state.BackupSha256) {
        throw 'Backup integrity check failed; the latest backup changed after it was created.'
    }
}

$backup = Get-Content -LiteralPath $resolvedBackup -Raw | ConvertFrom-Json
if ($hasConfigDigest) {
    $expectedConfigSha256 = [string]$state.ConfigSha256
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    if ($matchesLastApply -and -not [string]::IsNullOrWhiteSpace([string]$state.ConfigPath)) {
        $ConfigPath = [string]$state.ConfigPath
    }
    else {
        $ConfigPath = Join-Path $PSScriptRoot '..\config\macified.psd1'
    }
}
$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop).Path
if (-not [string]::IsNullOrWhiteSpace([string]$expectedConfigSha256)) {
    $actualConfigSha256 = (Get-FileHash -LiteralPath $resolvedConfigPath -Algorithm SHA256).Hash
    if ($actualConfigSha256 -ne [string]$expectedConfigSha256) {
        throw 'Configuration integrity check failed; the supplied config differs from the one used during apply.'
    }
}

Import-Module (Join-Path $PSScriptRoot 'Macified.Core.psm1') -Force
$config = Get-MacifiedConfig -Path $resolvedConfigPath
$allowedSettings = @{}
foreach ($setting in $config.Look.Settings) {
    if ($setting.Path -notmatch '^Software\\' -or $setting.Path -match '^Software\\Microsoft\\Windows\\CurrentVersion\\Policies') {
        throw "Refusing non-user-scoped or policy path in configuration: $($setting.Path)"
    }
    if ([string]$setting.Kind -notin @('DWord', 'String')) {
        throw "Unsupported setting kind in configuration: $($setting.Kind)"
    }
    $settingKey = "HKCU:\$($setting.Path)|$($setting.Name)"
    $allowedSettings[$settingKey] = [string]$setting.Kind
}

Write-Host ''
Write-Host ('Undo source: {0} (created {1})' -f $resolvedBackup, $backup.CreatedAt) -ForegroundColor Cyan
Write-Host ''

$plan = New-Object System.Collections.ArrayList

foreach ($item in $backup.Items) {
    if ($item.Path -notmatch '^HKCU:\\Software\\') {
        throw "Backup contains a non-HKCU path, refusing: $($item.Path)"
    }
    $settingKey = "$($item.Path)|$($item.Name)"
    if (-not $allowedSettings.ContainsKey($settingKey)) {
        throw "Backup contains an unknown or unconfigured setting, refusing: $($item.Path)\$($item.Name)"
    }
    if ([string]$item.Kind -ne $allowedSettings[$settingKey]) {
        throw "Backup kind does not match the configured setting, refusing: $($item.Path)\$($item.Name)"
    }
    if ($item.Existed -isnot [bool]) {
        throw "Backup has an invalid Existed flag, refusing: $($item.Path)\$($item.Name)"
    }
    if ($item.Existed -and $item.Kind -eq 'DWord') {
        $typedValue = 0
        if (-not [int]::TryParse([string]$item.Value, [ref]$typedValue)) {
            throw "Backup has an invalid DWord value, refusing: $($item.Path)\$($item.Name)"
        }
    }
    if ($item.Existed -and $item.Kind -eq 'String' -and $item.Value -isnot [string]) {
        throw "Backup has an invalid String value, refusing: $($item.Path)\$($item.Name)"
    }

    $key = $item.Path
    $current = $null
    $currentExists = $false
    $currentItem = Get-ItemProperty -LiteralPath $key -Name $item.Name -ErrorAction SilentlyContinue
    if ($null -ne $currentItem) {
        $current = $currentItem.($item.Name)
        $currentExists = $true
    }

    [void]$plan.Add([pscustomobject]@{
        Path        = $item.Path
        Name        = $item.Name
        Kind        = $item.Kind
        Existed     = [bool]$item.Existed
        Value       = $item.Value
        Current     = $(if ($currentExists) { $current } else { '<missing>' })
        NeedsChange = $true
    })
}

foreach ($item in $plan) {
    $target = if ($item.Existed) { 'restore ' + $item.Value } else { 'remove value' }
    $label = $item.Path + '\' + $item.Name
    Write-Host ('{0,-60} {1,-20} -> {2}' -f $label, [string]$item.Current, $target)
}
Write-Host ''

if (-not $Apply) {
    Write-Host 'DRY RUN: no registry value was modified. Re-run with -Apply.' -ForegroundColor Yellow
    exit 0
}

$failed = @()
foreach ($item in $plan) {
    try {
        $key = $item.Path
        if ($item.Existed) {
            if ($item.Kind -eq 'DWord') {
                Set-ItemProperty -LiteralPath $key -Name $item.Name -Value ([int]$item.Value) -Type DWord
            }
            else {
                Set-ItemProperty -LiteralPath $key -Name $item.Name -Value ([string]$item.Value) -Type String
            }
        }
        else {
            Remove-ItemProperty -LiteralPath $key -Name $item.Name -ErrorAction SilentlyContinue
        }
    }
    catch {
        $failed += $item
        Write-Host ('FAILED {0}\{1}: {2}' -f $item.Path, $item.Name, $_.Exception.Message) -ForegroundColor Red
    }
}

Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host ('{0} value(s) could not be restored (OS-protected or permissions).' -f $failed.Count) -ForegroundColor Red
    exit 2
}

Write-Host ('Restored {0} value(s) from {1}.' -f $plan.Count, $resolvedBackup) -ForegroundColor Green
exit 0
