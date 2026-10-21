#Requires -Version 5.1
<#
    Restores the most recent (or an explicit) look baseline backup.
    Dry run by default; writes only with -Apply.
#>
[CmdletBinding()]
param(
    [string]$BackupPath,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$stateDirectory = Join-Path $env:LOCALAPPDATA 'MacifiedWindows'
$statePath = Join-Path $stateDirectory 'last-apply.json'

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    if (Test-Path -LiteralPath $statePath) {
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
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
$backup = Get-Content -LiteralPath $resolvedBackup -Raw | ConvertFrom-Json

Write-Host ''
Write-Host ('Undo source: {0} (created {1})' -f $resolvedBackup, $backup.CreatedAt) -ForegroundColor Cyan
Write-Host ''

$plan = New-Object System.Collections.ArrayList

foreach ($item in $backup.Items) {
    if ($item.Path -notmatch '^HKCU:\\Software\\') {
        throw "Backup contains a non-HKCU path, refusing: $($item.Path)"
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
