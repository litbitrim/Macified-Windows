#Requires -Version 5.1
<#
    Read-only verifier for the mac-like baseline, app pins and hardware gates.
    It never writes to the registry, never starts an installer and never downloads
    anything. Exit codes: 0 = PASS/WARN only, 1 = at least one FAIL, 2 = setup error.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$RepoRoot,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is not reliably populated in param defaults on PowerShell 5.1.
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $scriptDirectory '..\config\macified.psd1'
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Join-Path $scriptDirectory '..\..'
}

try {
    Import-Module (Join-Path $scriptDirectory 'Macified.Core.psm1') -Force
    $config = Get-MacifiedConfig -Path $ConfigPath
    $repoRootPath = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path
}
catch {
    Write-Error "Cannot load configuration: $($_.Exception.Message)"
    exit 2
}

$results = New-Object System.Collections.ArrayList

function Add-Result {
    param(
        [string]$Area,
        [string]$Check,
        [string]$Status,
        [string]$Expected,
        [string]$Actual,
        [string]$Note
    )

    [void]$results.Add([pscustomobject]@{
        Area     = $Area
        Check    = $Check
        Status   = $Status
        Expected = $Expected
        Actual   = $Actual
        Note     = $Note
    })
}

function Format-TableLike {
    param($Rows)
    $Rows | ForEach-Object {
        '{0,-6} {1,-12} {2,-28} {3}' -f $_.Status, $_.Area, $_.Check, $_.Actual
        if ($_.Note) { '       note: ' + $_.Note }
    }
}

function Read-RegistryValue {
    param(
        [string]$Path,
        [string]$Name
    )

    $key = "HKCU:\$Path"
    if (-not (Test-Path -LiteralPath $key)) {
        return [pscustomobject]@{ Exists = $false; Value = $null }
    }

    $item = Get-ItemProperty -LiteralPath $key -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $item) {
        return [pscustomobject]@{ Exists = $false; Value = $null }
    }

    return [pscustomobject]@{ Exists = $true; Value = $item.$Name }
}

# --------------------------------------------------------------------------
# 1. Operating system profile
# --------------------------------------------------------------------------
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $nt = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$os.BuildNumber
    $ubr = [int]$nt.UBR
    $osActual = '{0} {1} {2}.{3}' -f $os.Caption, $nt.DisplayVersion, $build, $ubr
    $osOk = ($os.Caption -like "*$($config.Target.CaptionPattern)*") -and
            ($build -eq [int]$config.Target.VerifiedBuild)

    Add-Result 'OS' 'Verified target profile' $(if ($osOk) { 'PASS' } else { 'WARN' }) `
        ("{0} build {1}.{2}" -f $config.Target.CaptionPattern, $config.Target.VerifiedBuild, $config.Target.VerifiedUBR) `
        $osActual `
        $(if ($osOk) { '' } else { 'Build differs from the verified profile; settings were not validated on this build.' })
}
catch {
    Add-Result 'OS' 'Verified target profile' 'FAIL' 'Windows 11 Pro 26300' $_.Exception.Message ''
}

# --------------------------------------------------------------------------
# 2. Look settings (HKCU only)
# --------------------------------------------------------------------------
foreach ($setting in $config.Look.Settings) {
    $observed = Read-RegistryValue -Path $setting.Path -Name $setting.Name
    $comparison = Compare-MacifiedSetting -Setting $setting -Actual $observed.Value -ValueMissing (-not $observed.Exists)

    $actualText = if ($observed.Exists) { [string]$comparison.Actual }
        elseif ($comparison.UsedDefault) { [string]$comparison.Actual + ' (Windows default)' }
        else { '<missing>' }

    $lookStatus = $comparison.Status
    $lookNote = if ($comparison.Status -eq 'FAIL') { 'Run Apply-MacifiedLook.ps1 -Apply to align, or set it manually in Settings.' } else { '' }

    if ($lookStatus -eq 'FAIL' -and $setting.ContainsKey('Protected') -and [bool]$setting.Protected) {
        $lookStatus = 'WARN'
        $lookNote = 'OS-protected value; manual fallback only. ' + $setting.ProtectionNote
    }

    Add-Result 'Look' $setting.Label $lookStatus ([string]$comparison.Expected) $actualText $lookNote
}

# Accent colour: manual by design, therefore informational only.
try {
    $dwm = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\DWM' -ErrorAction SilentlyContinue
    $accentActual = if ($null -ne $dwm -and $null -ne $dwm.AccentColor) {
        Convert-MacDwordToHex -Value ([int64]$dwm.AccentColor)
    }
    else {
        '<missing>'
    }

    $accentStatus = if ($accentActual -eq $config.Look.Accent.Hex) { 'PASS' } else { 'WARN' }
    Add-Result 'Look' 'Accent colour (manual)' $accentStatus $config.Look.Accent.Hex $accentActual $config.Look.Accent.Note
}
catch {
    Add-Result 'Look' 'Accent colour (manual)' 'WARN' $config.Look.Accent.Hex '<unreadable>' $_.Exception.Message
}

# Wallpaper: hash only when a reference hash is configured.
try {
    $desktop = Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue
    $wallpaper = if ($null -ne $desktop) { $desktop.Wallpaper } else { $null }

    if ([string]::IsNullOrWhiteSpace($wallpaper)) {
        Add-Result 'Look' 'Wallpaper (manual)' 'WARN' 'user-supplied image' '<none>' $config.Look.Wallpaper.Note
    }
    elseif ([string]::IsNullOrWhiteSpace([string]$config.Look.Wallpaper.ExpectedSha256)) {
        Add-Result 'Look' 'Wallpaper (manual)' 'WARN' 'user-supplied image' $wallpaper `
            'No reference hash configured; verify the image visually.'
    }
    else {
        $hash = (Get-FileHash -LiteralPath $wallpaper -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
        $wallpaperStatus = if ($hash -and $hash.ToLowerInvariant() -eq ([string]$config.Look.Wallpaper.ExpectedSha256).ToLowerInvariant()) { 'PASS' } else { 'FAIL' }
        Add-Result 'Look' 'Wallpaper (manual)' $wallpaperStatus $config.Look.Wallpaper.ExpectedSha256 $wallpaper ''
    }
}
catch {
    Add-Result 'Look' 'Wallpaper (manual)' 'WARN' 'user-supplied image' '<unreadable>' $_.Exception.Message
}

# --------------------------------------------------------------------------
# 3. App pins
# --------------------------------------------------------------------------
$localSend = $config.Apps.LocalSend
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($null -eq $winget) {
    Add-Result 'Apps' 'LocalSend installed version' 'WARN' $localSend.Version '<winget missing>' 'Install or update via the official release, then re-run.'
}
else {
    try {
        $wingetOutput = (& winget list --id $localSend.WingetId --exact --disable-interactivity --accept-source-agreements 2>&1 | Out-String)
        if ($wingetOutput -match [regex]::Escape($localSend.WingetId)) {
            $versionMatch = [regex]::Match($wingetOutput, '\s(\d+\.\d+\.\d+)\s')
            $installedVersion = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { 'unknown' }
            $versionOk = $false
            if ($installedVersion -ne 'unknown') {
                try { $versionOk = ([version]$installedVersion -ge [version]$localSend.Version) } catch { $versionOk = $false }
            }
            Add-Result 'Apps' 'LocalSend installed version' $(if ($versionOk) { 'PASS' } else { 'WARN' }) `
                $localSend.Version $installedVersion $(if ($versionOk) { '' } else { 'Pinned version 1.18.2 or newer expected.' })
        }
        else {
            Add-Result 'Apps' 'LocalSend installed version' 'WARN' $localSend.Version '<not installed>' 'Optional: see docs/apps/localsend.md.'
        }
    }
    catch {
        Add-Result 'Apps' 'LocalSend installed version' 'WARN' $localSend.Version '<winget failed>' $_.Exception.Message
    }
}

try {
    $rules = @(Get-NetFirewallRule -DisplayName '*LocalSend*' -ErrorAction Stop)
    if ($rules.Count -eq 0) {
        Add-Result 'Apps' 'LocalSend firewall scope' 'WARN' 'inbound, Private only' '<no rule>' 'Create a Private-profile rule for TCP/UDP 53317 if discovery fails.'
    }
    else {
        $publicRules = @($rules | Where-Object { $_.Enabled -eq 'True' -and ([string]$_.Profile) -match 'Public' })
        Add-Result 'Apps' 'LocalSend firewall scope' $(if ($publicRules.Count -eq 0) { 'PASS' } else { 'WARN' }) `
            'inbound, Private only' ('{0} rule(s), {1} allow Public' -f $rules.Count, $publicRules.Count) `
            $(if ($publicRules.Count -eq 0) { '' } else { 'Public profile is broader than needed; restrict to Private manually.' })
    }
}
catch {
    Add-Result 'Apps' 'LocalSend firewall scope' 'WARN' 'inbound, Private only' '<unreadable>' $_.Exception.Message
}

try {
    $profiles = @(Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $_.IPv4Connectivity -eq 'Internet' })
    $publicProfiles = @($profiles | Where-Object { [string]$_.NetworkCategory -eq 'Public' })
    Add-Result 'Apps' 'Active network profile for discovery' $(if ($publicProfiles.Count -eq 0) { 'PASS' } else { 'WARN' }) `
        'Private' $(if ($profiles.Count -eq 0) { '<no internet profile>' } else { ($profiles | ForEach-Object { $_.Name + '=' + $_.NetworkCategory }) -join ', ' }) `
        $(if ($publicProfiles.Count -eq 0) { '' } else { 'LocalSend recommends a Private profile; change it manually in Settings.' })
}
catch {
    Add-Result 'Apps' 'Active network profile for discovery' 'WARN' 'Private' '<unreadable>' $_.Exception.Message
}

try {
    $virtualDisplays = @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object {
        $_.FriendlyName -match 'Virtual|Deskreen|IddSample'
    })
    Add-Result 'Apps' 'Virtual display for Deskreen' $(if ($virtualDisplays.Count -gt 0) { 'PASS' } else { 'WARN' }) `
        'virtual display adapter' $(if ($virtualDisplays.Count -gt 0) { ($virtualDisplays | ForEach-Object { $_.FriendlyName }) -join ', ' } else { '<none>' }) `
        'Needed for an extended desktop; mirroring works without it. Install manually and review the driver license.'
}
catch {
    Add-Result 'Apps' 'Virtual display for Deskreen' 'WARN' 'virtual display adapter' '<probe failed>' $_.Exception.Message
}

try {
    $uninstallRoots = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $deskreenEntry = Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'Deskreen*' } |
        Select-Object -First 1

    if ($null -eq $deskreenEntry) {
        Add-Result 'Apps' 'Deskreen CE installed version' 'WARN' $config.Apps.Deskreen.Version '<not installed>' `
            'Optional: see docs/apps/deskreen.md. Portable builds are not visible in the uninstall registry.'
    }
    else {
        $deskreenOk = ([string]$deskreenEntry.DisplayVersion -eq [string]$config.Apps.Deskreen.Version)
        Add-Result 'Apps' 'Deskreen CE installed version' $(if ($deskreenOk) { 'PASS' } else { 'WARN' }) `
            $config.Apps.Deskreen.Version ([string]$deskreenEntry.DisplayVersion) ''
    }
}
catch {
    Add-Result 'Apps' 'Deskreen CE installed version' 'WARN' $config.Apps.Deskreen.Version '<unreadable>' $_.Exception.Message
}

# --------------------------------------------------------------------------
# 4. Hardware gate: AirPods
# --------------------------------------------------------------------------
try {
    $btDevices = @(Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue)
    $audioEndpoints = @(Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue)

    $airPods = @($btDevices | Where-Object {
        $_.FriendlyName -like "*$($config.Gates.AirPods.RequiredPairedNamePattern)*" -and $_.Status -eq 'OK'
    })

    # AudioEndpoint instance ids are SWD\MMDEVAPI\..., so match on the endpoint name.
    # A running btaudio service is NOT required: modern HFP uses BTHHFENUM.
    $airPodsEndpoints = @($audioEndpoints | Where-Object { $_.FriendlyName -like '*AirPods*' })
    $activeEndpoints = @($airPodsEndpoints | Where-Object { $_.Status -eq 'OK' })

    $gate = Get-MacifiedAirPodsGate -PairedAirPods ($airPods.Count -gt 0) -BluetoothAudioEndpoint ($activeEndpoints.Count -gt 0)

    $radioNames = @($btDevices | Where-Object {
        $_.InstanceId -like 'USB\*' -or $_.FriendlyName -like '*Radio*'
    } | ForEach-Object { $_.FriendlyName })

    $gateNote = if ($gate.Status -eq 'PASS') {
        'Ready: paired device and active AirPods endpoint. Audible playback and mic still need a manual test.'
    }
    elseif ($gate.Status -eq 'WARN') {
        'Paired, but currently not connected (' + (@($airPodsEndpoints | ForEach-Object { $_.FriendlyName }) -join ', ') + '). Connect the AirPods and re-run.'
    }
    else {
        'Hardware gate open (' + ($gate.Reasons -join '; ') + '). Radios: ' + ($radioNames -join ', ')
    }

    Add-Result 'Gate' 'AirPods Pro 3 live test' $gate.Status 'paired device + active BT audio endpoint' `
        $(switch ($gate.Status) { 'PASS' { 'ready' } 'WARN' { 'paired, not connected' } default { 'blocked' } }) $gateNote
}
catch {
    Add-Result 'Gate' 'AirPods Pro 3 live test' 'FAIL' 'paired device + BT audio endpoint' '<probe failed>' $_.Exception.Message
}

# --------------------------------------------------------------------------
# 5. Fork hygiene and provenance
# --------------------------------------------------------------------------
$hygiene = Get-MacifiedRepoHygiene -Root $repoRootPath -ForbiddenExtensions $config.RepoHygiene.ForbiddenExtensions
Add-Result 'Repo' 'No binary artefacts in fork' $hygiene.Status ('no ' + ($config.RepoHygiene.ForbiddenExtensions -join ' ')) `
    ("{0} files checked" -f $hygiene.Checked) $(if ($hygiene.Files.Count -gt 0) { 'Unexpected: ' + ($hygiene.Files -join ', ') } else { '' })

$noticePath = Join-Path $repoRootPath 'NOTICE.md'
$noticeStatus = if (Test-Path -LiteralPath $noticePath) { 'PASS' } else { 'FAIL' }
Add-Result 'Repo' 'Provenance notice present' $noticeStatus 'NOTICE.md' $(if ($noticeStatus -eq 'PASS') { 'present' } else { 'missing' }) ''

$licensePath = Join-Path $repoRootPath 'macified\LICENSE'
$licenseStatus = if (Test-Path -LiteralPath $licensePath) { 'PASS' } else { 'FAIL' }
Add-Result 'Repo' 'Scope-limited license present' $licenseStatus 'macified\LICENSE' $(if ($licenseStatus -eq 'PASS') { 'present' } else { 'missing' }) ''

$designDoc = Join-Path $repoRootPath 'macified\docs\design-43pr.md'
$designStatus = if (Test-Path -LiteralPath $designDoc) { 'PASS' } else { 'FAIL' }
Add-Result 'Repo' 'Design inspiration documented' $designStatus 'docs/design-43pr.md' $(if ($designStatus -eq 'PASS') { 'present' } else { 'missing' }) 'Optional third-party ideas must stay attributed.'

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
$failCount = @($results | Where-Object { $_.Status -eq 'FAIL' }).Count
$warnCount = @($results | Where-Object { $_.Status -eq 'WARN' }).Count
$passCount = @($results | Where-Object { $_.Status -eq 'PASS' }).Count

if ($Json) {
    [pscustomobject]@{
        GeneratedAt = (Get-Date).ToString('s')
        Summary     = [pscustomobject]@{ Pass = $passCount; Warn = $warnCount; Fail = $failCount }
        Results     = $results
    } | ConvertTo-Json -Depth 5
}
else {
    Write-Host ''
    Write-Host 'Macified Windows - state check (read-only)' -ForegroundColor Cyan
    Write-Host ('Profile: {0}' -f $repoRootPath)
    Write-Host ''
    Format-TableLike -Rows $results | Write-Host
    Write-Host ''
    Write-Host ('Summary: PASS {0}  WARN {1}  FAIL {2}' -f $passCount, $warnCount, $failCount)
    if ($failCount -eq 0) {
        Write-Host 'Result: PASS (warnings are documented, non-blocking findings)' -ForegroundColor Green
    }
    else {
        Write-Host 'Result: FAIL (see notes above)' -ForegroundColor Red
    }
}

exit $(if ($failCount -eq 0) { 0 } else { 1 })
