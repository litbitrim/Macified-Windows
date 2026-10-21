#Requires -Version 5.1
<#
    Offline integrity check for a manually downloaded installer or archive.
    It does not download or start anything; it only reads the file.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$Sha256,

    [string]$ExpectedPublisher
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "File not found: $Path"
}

$file = Get-Item -LiteralPath $Path
$hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$hashOk = ($hash -eq $Sha256.ToLowerInvariant())

$signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
$publisherOk = $null
$publisher = '<none>'
if ($null -ne $signature.SignerCertificate) {
    $publisher = $signature.SignerCertificate.Subject
    if (-not [string]::IsNullOrWhiteSpace($ExpectedPublisher)) {
        $publisherOk = $publisher -like "*$ExpectedPublisher*"
    }
}

$version = '<none>'
if ($null -ne $file.VersionInfo -and -not [string]::IsNullOrWhiteSpace($file.VersionInfo.FileVersion)) {
    $version = $file.VersionInfo.FileVersion
}

Write-Host ''
Write-Host 'Download integrity report' -ForegroundColor Cyan
Write-Host ('File      : {0}' -f $file.FullName)
Write-Host ('Size      : {0} bytes' -f $file.Length)
Write-Host ('SHA256    : {0}' -f $hash)
Write-Host ('Expected  : {0}' -f $Sha256.ToLowerInvariant())
Write-Host ('Hash      : {0}' -f $(if ($hashOk) { 'MATCH' } else { 'MISMATCH' })) -ForegroundColor $(if ($hashOk) { 'Green' } else { 'Red' })
Write-Host ('Signature : {0}' -f $signature.Status)
Write-Host ('Publisher : {0}' -f $publisher)
if ($null -ne $publisherOk) {
    Write-Host ('Publisher : {0}' -f $(if ($publisherOk) { 'MATCH' } else { 'MISMATCH' })) -ForegroundColor $(if ($publisherOk) { 'Green' } else { 'Red' })
}
Write-Host ('Version   : {0}' -f $version)
Write-Host ''

if (-not $hashOk) {
    Write-Host 'Result: FAIL (hash mismatch - do not run this file)' -ForegroundColor Red
    exit 1
}

if ($null -ne $publisherOk -and -not $publisherOk) {
    Write-Host 'Result: FAIL (publisher mismatch)' -ForegroundColor Red
    exit 1
}

Write-Host 'Result: PASS (hash matches; signature status shown above)' -ForegroundColor Green
exit 0
