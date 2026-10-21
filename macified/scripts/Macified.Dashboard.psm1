#Requires -Version 5.1
<#
    Read-only status collector for the Macified dashboard.
    Every function here only reads processes, registry values, PnP devices,
    firewall rules, network profiles and TCP tables. Nothing is written,
    started or installed.
#>

Import-Module (Join-Path $PSScriptRoot 'Macified.Core.psm1')

$script:UninstallRoots = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$script:Cache = @{}

function Get-MacifiedCachedValue {
    param(
        [string]$Key,
        [int]$Seconds,
        [scriptblock]$Factory
    )

    $now = Get-Date
    $entry = $script:Cache[$Key]
    if ($null -ne $entry -and $entry.Until -gt $now) {
        return $entry.Value
    }

    $value = & $Factory
    $script:Cache[$Key] = @{ Value = $value; Until = $now.AddSeconds($Seconds) }
    return $value
}

function Get-MacifiedBaselineSection {
    param([hashtable]$Config)

    $settings = @()
    $pass = 0
    $warn = 0
    $fail = 0

    foreach ($setting in $Config.Look.Settings) {
        $key = "HKCU:\$($setting.Path)"
        $exists = Test-Path -LiteralPath $key
        $value = $null
        $valueExists = $false

        if ($exists) {
            $item = Get-ItemProperty -LiteralPath $key -Name $setting.Name -ErrorAction SilentlyContinue
            if ($null -ne $item) {
                $value = $item.($setting.Name)
                $valueExists = $true
            }
        }

        $comparison = Compare-MacifiedSetting -Setting $setting -Actual $value -ValueMissing (-not $valueExists)
        $status = $comparison.Status

        if ($status -eq 'FAIL' -and $setting.ContainsKey('Protected') -and [bool]$setting.Protected) {
            $status = 'WARN'
        }

        switch ($status) {
            'PASS' { $pass++ }
            'WARN' { $warn++ }
            default { $fail++ }
        }

        $settings += [ordered]@{
            id     = $setting.Id
            label  = $setting.Label
            status = $status
        }
    }

    $taskbarProtected = $false
    foreach ($setting in $Config.Look.Settings) {
        if ($setting.Id -eq 'TaskbarDa' -and $setting.ContainsKey('Protected')) {
            $taskbarProtected = [bool]$setting.Protected
        }
    }

    $seelen = Get-Process -Name 'seelen-ui' -ErrorAction SilentlyContinue | Select-Object -First 1

    return [ordered]@{
        pass               = $pass
        warn               = $warn
        fail               = $fail
        settings           = $settings
        taskbarDaProtected = $taskbarProtected
        seelenRunning      = ($null -ne $seelen)
        taskbarMode        = $(if ($null -ne $seelen) { 'Seelen UI' } else { 'Windows taskbar' })
    }
}

function Get-MacifiedLocalSendSection {
    $result = [ordered]@{
        installed        = $false
        running          = $false
        version          = $null
        listening        = $false
        port             = 53317
        peers            = @()
        firewallProfiles = @()
        networkProfiles  = @()
        status           = 'missing'
        error            = $null
    }

    try {
        $entry = Get-ItemProperty -Path $script:UninstallRoots -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'LocalSend*' } |
            Select-Object -First 1

        $process = Get-Process -Name 'localsend_app' -ErrorAction SilentlyContinue | Select-Object -First 1
        $exe = $null

        if ($null -ne $process -and -not [string]::IsNullOrWhiteSpace($process.Path)) {
            $exe = $process.Path
        }
        elseif ($null -ne $entry -and -not [string]::IsNullOrWhiteSpace($entry.InstallLocation)) {
            $exe = Join-Path $entry.InstallLocation 'localsend_app.exe'
        }
        else {
            $exe = Join-Path $env:ProgramFiles 'LocalSend\localsend_app.exe'
        }

        if (Test-Path -LiteralPath $exe) {
            $result.installed = $true
            $version = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
            if (-not [string]::IsNullOrWhiteSpace($version)) {
                $result.version = ($version -split '\+')[0]
            }
        }

        if ($null -ne $entry -and -not [string]::IsNullOrWhiteSpace($entry.DisplayVersion)) {
            $result.installed = $true
            if ([string]::IsNullOrWhiteSpace($result.version)) {
                $result.version = $entry.DisplayVersion
            }
        }

        if ($null -ne $process) {
            $result.running = $true
        }

        # One TCP table read covers listener and transfer connections.
        $connections = @(Get-NetTCPConnection -LocalPort $result.port -ErrorAction SilentlyContinue)
        $result.listening = (@($connections | Where-Object { $_.State -eq 'Listen' }).Count -gt 0)

        $established = @($connections | Where-Object { $_.State -eq 'Established' })
        $seen = @{}
        foreach ($connection in $established) {
            $address = [string]$connection.RemoteAddress
            if ($address -in @('0.0.0.0', '::', '127.0.0.1', '::1')) {
                continue
            }
            $peerKey = '{0}:{1}' -f $address, $connection.RemotePort
            if (-not $seen.ContainsKey($peerKey)) {
                $seen[$peerKey] = $true
                $result.peers += [ordered]@{
                    address = $address
                    port    = [int]$connection.RemotePort
                }
            }
        }

        $result.firewallProfiles = @(Get-MacifiedCachedValue -Key 'localsend-firewall' -Seconds 30 -Factory {
            $profiles = @()
            $rules = @(Get-NetFirewallRule -DisplayName '*LocalSend*' -ErrorAction SilentlyContinue)
            foreach ($rule in $rules) {
                foreach ($profile in (([string]$rule.Profile) -split ',')) {
                    $trimmed = $profile.Trim()
                    if ($trimmed -and $profiles -notcontains $trimmed) {
                        $profiles += $trimmed
                    }
                }
            }
            return $profiles
        })

        $network = @(Get-MacifiedCachedValue -Key 'network-profiles' -Seconds 10 -Factory {
            @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
        })
        $result.networkProfiles = @($network | ForEach-Object {
            [ordered]@{ name = $_.Name; category = [string]$_.NetworkCategory }
        })

        $result.status = if ($result.peers.Count -gt 0) { 'active' }
            elseif ($result.listening) { 'ready' }
            elseif ($result.installed) { 'offline' }
            else { 'missing' }
    }
    catch {
        $result.status = 'error'
        $result.error = $_.Exception.Message
    }

    return $result
}

function Get-MacifiedAirPodsSection {
    $result = [ordered]@{
        paired     = $false
        connected  = $false
        deviceName = $null
        endpoints  = @()
        status     = 'missing'
        error      = $null
    }

    try {
        $bluetooth = @(Get-MacifiedCachedValue -Key 'bluetooth-devices' -Seconds 5 -Factory {
            @(Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue)
        })
        $devices = @($bluetooth | Where-Object {
            $_.FriendlyName -like '*AirPods*' -and $_.InstanceId -like 'BTHENUM\DEV_*'
        })

        if ($devices.Count -eq 0) {
            $devices = @($bluetooth | Where-Object { $_.FriendlyName -like '*AirPods*' })
        }

        if ($devices.Count -gt 0) {
            $result.paired = $true
            $result.deviceName = $devices[0].FriendlyName
        }

        $audioEndpoints = @(Get-MacifiedCachedValue -Key 'audio-endpoints' -Seconds 5 -Factory {
            @(Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue)
        })
        $rawEndpoints = @($audioEndpoints | Where-Object { $_.FriendlyName -like '*AirPods*' })

        $map = @{}
        foreach ($endpoint in $rawEndpoints) {
            $name = [string]$endpoint.FriendlyName
            $active = ($endpoint.Status -eq 'OK')
            $kind = if ($name -match 'Hands-Free|Handsfree') { 'HFP' } else { 'A2DP' }

            if (-not $map.ContainsKey($name) -or ($active -and -not $map[$name].active)) {
                $map[$name] = [ordered]@{
                    name   = $name
                    kind   = $kind
                    active = $active
                    status = $(if ($active) { 'active' } else { 'idle' })
                }
            }
        }

        $result.endpoints = @($map.Values | Sort-Object { $_.kind })
        $result.connected = (@($result.endpoints | Where-Object { $_.active }).Count -gt 0)

        $result.status = if ($result.connected) { 'connected' }
            elseif ($result.paired) { 'paired' }
            else { 'missing' }
    }
    catch {
        $result.status = 'error'
        $result.error = $_.Exception.Message
    }

    return $result
}

function Get-MacifiedDeskreenSection {
    $result = [ordered]@{
        installed      = $false
        running        = $false
        version        = $null
        virtualDisplay = $false
        connections    = 0
        status         = 'missing'
        error          = $null
    }

    try {
        $entry = Get-ItemProperty -Path $script:UninstallRoots -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'Deskreen*' } |
            Select-Object -First 1

        $process = Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -like 'deskreen*' } |
            Select-Object -First 1

        if ($null -ne $entry) {
            $result.installed = $true
            $result.version = [string]$entry.DisplayVersion
        }

        if ($null -ne $process) {
            $result.installed = $true
            $result.running = $true

            if ([string]::IsNullOrWhiteSpace($result.version) -and -not [string]::IsNullOrWhiteSpace($process.Path)) {
                $result.version = (Get-Item -LiteralPath $process.Path).VersionInfo.ProductVersion
            }

            $result.connections = @(Get-NetTCPConnection -OwningProcess $process.Id -State Established -ErrorAction SilentlyContinue).Count
        }

        $displays = @(Get-MacifiedCachedValue -Key 'display-devices' -Seconds 10 -Factory {
            @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue)
        } | Where-Object { $_.FriendlyName -match 'Virtual|Deskreen|IddSample' })
        $result.virtualDisplay = ($displays.Count -gt 0)

        $result.status = if ($result.connections -gt 0) { 'active' }
            elseif ($result.installed) { 'ready' }
            else { 'missing' }
    }
    catch {
        $result.status = 'error'
        $result.error = $_.Exception.Message
    }

    return $result
}

function Get-MacifiedDashboardStatus {
    [CmdletBinding()]
    param(
        [string]$ConfigPath,
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Join-Path $PSScriptRoot '..\config\macified.psd1'
    }

    $config = Get-MacifiedConfig -Path $ConfigPath
    $nt = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $productName = [string]$nt.ProductName
    # Windows 11 retains a Windows 10 ProductName in this registry value.
    if ([int]$nt.CurrentBuild -ge 22000 -and $productName -match '^Windows 10\b') {
        $productName = $productName -replace '^Windows 10\b', 'Windows 11'
    }

    return [ordered]@{
        generatedAt = (Get-Date).ToString('o')
        host        = [ordered]@{
            name           = $env:COMPUTERNAME
            os             = $productName
            build          = ('{0}.{1}' -f $nt.CurrentBuild, $nt.UBR)
            displayVersion = [string]$nt.DisplayVersion
        }
        baseline    = Get-MacifiedBaselineSection -Config $config
        localsend   = Get-MacifiedLocalSendSection
        airpods     = Get-MacifiedAirPodsSection
        deskreen    = Get-MacifiedDeskreenSection
    }
}

Export-ModuleMember -Function @(
    'Get-MacifiedDashboardStatus'
)
