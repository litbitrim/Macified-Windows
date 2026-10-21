#Requires -Version 5.1
<#
    Offline integrity check for a manually downloaded installer or archive.
    It does not download or start anything; it only reads the file.
    -ExpectedPublisher must exactly match the signing certificate's simple name.
    Exit codes: 0 = hash and requested valid publisher match; 1 = mismatch;
    2 = hash matches but publisher verification was not requested.
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
$publisherCheckRequested = -not [string]::IsNullOrWhiteSpace($ExpectedPublisher)

$signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
$publisherOk = $false
$publisher = '<none>'
$publisherName = '<none>'
if ($null -ne $signature.SignerCertificate) {
    $publisher = $signature.SignerCertificate.Subject
    $publisherName = $signature.SignerCertificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
    $publisherOk = ($publisherCheckRequested -and $signature.Status -eq 'Valid' -and [string]::Equals($publisherName, $ExpectedPublisher.Trim(), [StringComparison]::OrdinalIgnoreCase))
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
Write-Host ('Publisher name: {0}' -f $publisherName)
Write-Host ('Publisher check: {0}' -f $(if (-not $publisherCheckRequested) { 'NOT REQUESTED' } elseif ($publisherOk) { 'MATCH' } else { 'MISMATCH' })) -ForegroundColor $(if (-not $publisherCheckRequested) { 'Yellow' } elseif ($publisherOk) { 'Green' } else { 'Red' })
Write-Host ('Version   : {0}' -f $version)
Write-Host ''

if (-not $hashOk) {
    Write-Host 'Result: FAIL (hash mismatch - do not run this file)' -ForegroundColor Red
    exit 1
}

if ($publisherCheckRequested -and -not $publisherOk) {
    Write-Host 'Result: FAIL (publisher missing, invalid signature, or mismatch)' -ForegroundColor Red
    exit 1
}

if (-not $publisherCheckRequested) {
    Write-Host 'Result: WARN (hash matches; publisher not checked; signature status shown above)' -ForegroundColor Yellow
    exit 2
}

Write-Host 'Result: PASS (hash and valid publisher signature match)' -ForegroundColor Green
exit 0
