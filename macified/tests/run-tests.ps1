#Requires -Version 5.1
<#
    Runs the Pester suite and propagates failures as exit code 1.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    Import-Module Pester -MinimumVersion 3.0 -ErrorAction Stop
}
catch {
    Write-Error "Pester 3.0+ is required: $($_.Exception.Message)"
    exit 2
}

$testFile = Join-Path $PSScriptRoot 'Macified.Core.Tests.ps1'
$result = Invoke-Pester -Script $testFile -PassThru

if ($null -eq $result) {
    Write-Error 'Pester returned no result.'
    exit 2
}

Write-Host ''
Write-Host ('Pester: total {0}, passed {1}, failed {2}, skipped {3}' -f `
    $result.TotalCount, $result.PassedCount, $result.FailedCount, $result.SkippedCount)

if ($result.FailedCount -gt 0) {
    exit 1
}

exit 0
