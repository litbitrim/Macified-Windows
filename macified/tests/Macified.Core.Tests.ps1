$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$repo = Split-Path -Parent $root

Import-Module (Join-Path $root 'scripts\Macified.Core.psm1') -Force
Import-Module (Join-Path $root 'scripts\Macified.Dashboard.psm1') -Force
$config = Get-MacifiedConfig -Path (Join-Path $root 'config\macified.psd1')

Describe 'Configuration' {
    It 'targets the verified Windows 11 26H2 profile' {
        $config.SchemaVersion | Should Be 1
        $config.Target.VerifiedBuild | Should Be 26300
        $config.Target.VerifiedDisplayVersion | Should Be '26H2'
        $config.Target.CaptionPattern | Should Be 'Windows 11 Pro'
    }

    It 'defines exactly eight look settings' {
        @($config.Look.Settings).Count | Should Be 8
    }

    It 'keeps every look value user-scoped and policy-free' {
        foreach ($setting in $config.Look.Settings) {
            $setting.Path | Should Match '^Software\\'
            $setting.Path | Should Not Match 'Policies'
            $setting.Kind | Should Be 'DWord'
        }
    }

    It 'documents a Windows default for every setting' {
        foreach ($setting in $config.Look.Settings) {
            $setting.ContainsKey('Default') | Should Be $true
        }
    }

    It 'pins LocalSend 1.18.2 and Deskreen CE 3.2.16 with 64-char hashes' {
        $config.Apps.LocalSend.Version | Should Be '1.18.2'
        $config.Apps.LocalSend.WingetId | Should Be 'LocalSend.LocalSend'
        $config.Apps.Deskreen.Version | Should Be '3.2.16'

        foreach ($app in @($config.Apps.LocalSend, $config.Apps.Deskreen)) {
            foreach ($asset in $app.Assets) {
                $asset.Sha256 | Should Match '^[0-9a-f]{64}$'
            }
        }
    }

    It 'marks TaskbarDa as OS-protected with a manual fallback' {
        $protected = @($config.Look.Settings | Where-Object { $_.ContainsKey('Protected') -and $_.Protected })
        $protected.Count | Should Be 1
        $protected[0].Id | Should Be 'TaskbarDa'
        $protected[0].ProtectionNote | Should Match 'Seelen UI'
    }

    It 'records the user-confirmed audible stereo test' {
        $config.Gates.AirPods.LiveTest | Should Be 'stereo-audible-confirmed'
        @($config.Gates.AirPods.Evidence).Count | Should BeGreaterThan 3
    }
}

Describe 'Colour conversion' {
    It 'converts macOS blue to an ABGR DWORD' {
        (Convert-MacHexToDword -Hex '#007AFF') | Should Be ([uint32]4294932992)
    }

    It 'round-trips a DWORD back to hex' {
        (Convert-MacDwordToHex -Value 4294932992) | Should Be '#007AFF'
    }

    It 'handles negative Int32 registry values' {
        (Convert-MacDwordToHex -Value (-34304)) | Should Be '#007AFF'
    }

    It 'rejects malformed colours' {
        { Convert-MacHexToDword -Hex 'blue' } | Should Throw
    }
}

Describe 'Setting comparison' {
    $setting = @{ Id = 'Test'; Kind = 'DWord'; Expected = 0; Default = 2 }

    It 'passes on a matching value' {
        (Compare-MacifiedSetting -Setting $setting -Actual 0).Status | Should Be 'PASS'
    }

    It 'fails on drift' {
        (Compare-MacifiedSetting -Setting $setting -Actual 1).Status | Should Be 'FAIL'
    }

    It 'uses the documented Windows default when the value is missing' {
        $result = Compare-MacifiedSetting -Setting $setting -Actual $null -ValueMissing $true
        $result.Status | Should Be 'FAIL'
        $result.Actual | Should Be 2
        $result.UsedDefault | Should Be $true
    }

    It 'fails hard when no default is documented' {
        $noDefault = @{ Id = 'Test'; Kind = 'DWord'; Expected = 0 }
        $result = Compare-MacifiedSetting -Setting $noDefault -Actual $null -ValueMissing $true
        $result.Reason | Should Be 'value-missing'
        $result.UsedDefault | Should Be $false
    }
}

Describe 'AirPods hardware gate' {
    It 'fails without a paired device and endpoint' {
        (Get-MacifiedAirPodsGate -PairedAirPods $false -BluetoothAudioEndpoint $false).Status | Should Be 'FAIL'
    }

    It 'warns when paired but no endpoint is active' {
        (Get-MacifiedAirPodsGate -PairedAirPods $true -BluetoothAudioEndpoint $false).Status | Should Be 'WARN'
    }

    It 'passes only when device and endpoint exist' {
        (Get-MacifiedAirPodsGate -PairedAirPods $true -BluetoothAudioEndpoint $true).Status | Should Be 'PASS'
    }
}

Describe 'Repository hygiene' {
    It 'contains no forbidden binary artefacts' {
        $result = Get-MacifiedRepoHygiene -Root $repo -ForbiddenExtensions $config.RepoHygiene.ForbiddenExtensions
        $result.Status | Should Be 'PASS'
        $result.Checked | Should BeGreaterThan 10
    }
}

Describe 'Documentation' {
    It 'has a provenance notice naming the archive status and missing license' {
        $notice = Get-Content -LiteralPath (Join-Path $repo 'NOTICE.md') -Raw
        $notice | Should Match 'archiviert'
        $notice | Should Match 'license: null'
        $notice | Should Match 'AGPL-3.0'
        $notice | Should Match 'Apache-2.0'
        $notice | Should Match 'MIT'
    }

    It 'keeps the license scope limited to macified' {
        $license = Get-Content -LiteralPath (Join-Path $repo 'macified\LICENSE') -Raw
        $license | Should Match 'exclusively'
        $license | Should Match 'does not apply'
    }

    It 'documents setup, rollback and visual acceptance' {
        $setup = Get-Content -LiteralPath (Join-Path $repo 'macified\docs\setup.md') -Raw
        $rollback = Get-Content -LiteralPath (Join-Path $repo 'macified\docs\rollback.md') -Raw
        $verify = Get-Content -LiteralPath (Join-Path $repo 'macified\docs\verify.md') -Raw

        $setup | Should Match 'Apply-MacifiedLook'
        $rollback | Should Match 'Undo-MacifiedLook'
        $verify | Should Match 'V13'
        $verify | Should Match 'AirPods'

        $dashboard = Get-Content -LiteralPath (Join-Path $repo 'macified\docs\dashboard.md') -Raw
        $dashboard | Should Match 'Start-MacifiedDashboard'
        $dashboard | Should Match '127\.0\.0\.1'
        $dashboard | Should Match 'read-only'
    }

    It 'documents every pinned app' {
        (Get-Content -LiteralPath (Join-Path $repo 'macified\docs\apps\localsend.md') -Raw) | Should Match 'Apache-2.0'
        (Get-Content -LiteralPath (Join-Path $repo 'macified\docs\apps\deskreen.md') -Raw) | Should Match 'AGPL-3.0'
        (Get-Content -LiteralPath (Join-Path $repo 'macified\docs\apps\airpods-pro-3.md') -Raw) | Should Match 'READY'
    }

    It 'attributes the optional design inspiration and copies no code' {
        $design = Get-Content -LiteralPath (Join-Path $repo 'macified\docs\design-43pr.md') -Raw
        $design | Should Match 'MIT'
        $design | Should Match '43PR/dotfiles'
        $design | Should Match 'kein Code'
    }

    It 'contains no absolute user paths in docs or scripts' {
        $paths = @(Get-ChildItem -LiteralPath (Join-Path $repo 'macified') -Recurse -File |
            Where-Object { $_.Extension -in @('.md', '.ps1', '.psm1', '.psd1') })
        foreach ($file in $paths) {
            (Get-Content -LiteralPath $file.FullName -Raw) | Should Not Match 'C:\\Users\\'
        }
    }
}

Describe 'Dry-run integration' {
    It 'applies nothing without -Apply' {
        $before = @{}
        foreach ($setting in $config.Look.Settings) {
            $key = "HKCU:\$($setting.Path)"
            $value = (Get-ItemProperty -LiteralPath $key -Name $setting.Name -ErrorAction SilentlyContinue).($setting.Name)
            $before[$setting.Id] = $value
        }

        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\Apply-MacifiedLook.ps1') 2>&1 | Out-String
        $LASTEXITCODE | Should Be 0
        $output | Should Match 'No registry value was modified'

        foreach ($setting in $config.Look.Settings) {
            $key = "HKCU:\$($setting.Path)"
            $after = (Get-ItemProperty -LiteralPath $key -Name $setting.Name -ErrorAction SilentlyContinue).($setting.Name)
            $after | Should Be $before[$setting.Id]
        }
    }

    It 'rejects a backup that points outside HKCU' {
        $fixture = Join-Path $env:TEMP ('macified-undo-bad-{0}.json' -f [guid]::NewGuid())
        $payload = [pscustomobject]@{
            CreatedAt = '2026-10-21T12:00:00'
            Items     = @([pscustomobject]@{
                Path    = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
                Name    = 'MacifiedTestValue'
                Kind    = 'String'
                Existed = $true
                Value   = 'x'
            })
        }

        try {
            $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixture -Encoding UTF8
            $code = 0
            $output = ''
            try {
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\Undo-MacifiedLook.ps1') -BackupPath $fixture 2>&1 | Out-String
                $code = $LASTEXITCODE
            }
            catch {
                $output = $_.Exception.Message
                $code = 1
            }

            $code | Should Not Be 0
            $output | Should Match 'non-HKCU'
        }
        finally {
            Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue
        }
    }

    It 'undo dry-run accepts a backup and writes nothing' {
        $fixture = Join-Path $env:TEMP ('macified-undo-{0}.json' -f [guid]::NewGuid())
        $payload = [pscustomobject]@{
            CreatedAt = '2026-10-21T12:00:00'
            Items     = @([pscustomobject]@{
                Path    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                Name    = 'MacifiedTestValueThatDoesNotExist'
                Kind    = 'DWord'
                Existed = $false
                Value   = $null
            })
        }

        try {
            $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixture -Encoding UTF8
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\Undo-MacifiedLook.ps1') -BackupPath $fixture 2>&1 | Out-String
            $LASTEXITCODE | Should Be 0
            $output | Should Match 'DRY RUN'
            $output | Should Match 'remove value'
        }
        finally {
            Remove-Item -LiteralPath $fixture -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Dashboard' {
    It 'ships the three static assets and no external requests' {
        foreach ($name in @('index.html', 'styles.css', 'app.js')) {
            $path = Join-Path $root "dashboard\$name"
            Test-Path -LiteralPath $path -PathType Leaf | Should Be $true
            (Get-Content -LiteralPath $path -Raw) | Should Not Match 'https?://'
        }
    }

    It 'renders status text without HTML injection sinks' {
        $script = Get-Content -LiteralPath (Join-Path $root 'dashboard\app.js') -Raw
        $script | Should Match 'textContent'
        $script | Should Not Match 'innerHTML|insertAdjacentHTML|document\.write|eval\('
    }

    It 'collects a snapshot with all sections and eight baseline values' {
        $snapshot = Get-MacifiedDashboardStatus -ConfigPath (Join-Path $root 'config\macified.psd1')

        $snapshot.generatedAt | Should Match '^\d{4}-\d{2}-\d{2}T'
        $snapshot.localsend.status | Should Match '^(active|ready|offline|missing|error)$'
        $snapshot.airpods.status | Should Match '^(connected|paired|missing|error)$'
        $snapshot.deskreen.status | Should Match '^(active|ready|missing|error)$'
        @($snapshot.baseline.settings).Count | Should Be 8
        ($snapshot.baseline.pass + $snapshot.baseline.warn + $snapshot.baseline.fail) | Should Be 8
        $snapshot.baseline.taskbarMode | Should Match 'Seelen UI|Windows taskbar'
    }

    It 'binds the server to loopback and serves GET only' {
        $server = Get-Content -LiteralPath (Join-Path $root 'scripts\Start-MacifiedDashboard.ps1') -Raw
        $server | Should Match 'IPAddress\]::Loopback'
        $server | Should Match "method -ne 'GET'"
        $server | Should Match "frame-ancestors 'none'"
    }

    It 'has no write or install path in the collector or server' {
        foreach ($name in @('Macified.Dashboard.psm1', 'Start-MacifiedDashboard.ps1')) {
            $content = Get-Content -LiteralPath (Join-Path $root "scripts\$name") -Raw
            $content | Should Not Match 'Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Start-Process|Invoke-WebRequest|winget install'
        }
    }
}

Describe 'Script guardrails' {
    It 'keeps the verifier read-only' {
        $verifier = Get-Content -LiteralPath (Join-Path $root 'scripts\Test-MacifiedState.ps1') -Raw
        $verifier | Should Not Match 'Set-ItemProperty|New-ItemProperty|Remove-ItemProperty'
        $verifier | Should Not Match 'Start-Process|Invoke-WebRequest|winget install'
    }

    It 'defaults the apply script to dry-run' {
        $apply = Get-Content -LiteralPath (Join-Path $root 'scripts\Apply-MacifiedLook.ps1') -Raw
        $apply | Should Match 'if \(-not \$Apply\)'
        $apply | Should Match 'No registry value was modified'
    }

    It 'reports protected values instead of forcing them' {
        $apply = Get-Content -LiteralPath (Join-Path $root 'scripts\Apply-MacifiedLook.ps1') -Raw
        $apply | Should Match 'MANUAL'
        $apply | Should Match 'Protected'

        $undo = Get-Content -LiteralPath (Join-Path $root 'scripts\Undo-MacifiedLook.ps1') -Raw
        $undo | Should Match 'could not be restored'
    }

    It 'never writes to HKLM or starts a process' {
        foreach ($name in @('Apply-MacifiedLook.ps1', 'Undo-MacifiedLook.ps1', 'Test-DownloadIntegrity.ps1')) {
            $content = Get-Content -LiteralPath (Join-Path $root "scripts\$name") -Raw
            $content | Should Not Match 'HKLM:'
            $content | Should Not Match 'Start-Process'
        }
    }

    It 'does not import upstream scripts or reference the archived packages' {
        $files = @()
        foreach ($dir in @('scripts', 'config')) {
            $files += @(Get-ChildItem -LiteralPath (Join-Path $root $dir) -Recurse -File |
                Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') })
        }
        foreach ($file in $files) {
            (Get-Content -LiteralPath $file.FullName -Raw) | Should Not Match 'ThemePatcher|7tsp|StartAllBack|ExplorerBlurMica'
        }
    }
}
