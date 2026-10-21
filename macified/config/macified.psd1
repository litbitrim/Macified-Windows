@{
    SchemaVersion = 1
    Generated     = '2026-10-21'

    # Verified target profile. Other builds are reported as WARN, never silently accepted.
    Target = @{
        CaptionPattern         = 'Windows 11 Pro'
        VerifiedBuild          = 26300
        VerifiedUBR            = 9711
        VerifiedDisplayVersion = '26H2'
        Architecture           = '64-Bit'
    }

    Look = @{
        # Wallpaper stays manual on purpose: Apple wallpapers are not licensed for
        # redistribution, and the upstream repo ships them without a license.
        Wallpaper = @{
            Mode           = 'Manual'
            ExpectedSha256 = $null
            Note           = 'Use an image you own or a permissively licensed one. No files are shipped here.'
        }

        # Accent must be set through Settings: writing AccentColor alone does not
        # rebuild the Windows accent palette reliably.
        Accent = @{
            Mode = 'Manual'
            Hex  = '#007AFF'
            Note = 'Settings > Personalization > Colors > Custom color. Scripts only verify the stored value.'
        }

        # Only HKCU values, all user-scoped and reversible. No HKLM, no system files.
        Settings = @(
            @{
                Id       = 'AppsUseLightTheme'
                Label    = 'Dark mode for apps'
                Path     = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
                Name     = 'AppsUseLightTheme'
                Kind     = 'DWord'
                Expected = 0
                Default  = 1
            }
            @{
                Id       = 'SystemUsesLightTheme'
                Label    = 'Dark mode for Windows surfaces'
                Path     = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
                Name     = 'SystemUsesLightTheme'
                Kind     = 'DWord'
                Expected = 0
                Default  = 1
            }
            @{
                Id       = 'EnableTransparency'
                Label    = 'Transparency effects on'
                Path     = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
                Name     = 'EnableTransparency'
                Kind     = 'DWord'
                Expected = 1
                Default  = 1
            }
            @{
                Id       = 'TaskbarAl'
                Label    = 'Taskbar icons centered'
                Path     = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                Name     = 'TaskbarAl'
                Kind     = 'DWord'
                Expected = 1
                Default  = 1
            }
            @{
                Id       = 'SearchboxTaskbarMode'
                Label    = 'Taskbar search hidden'
                Path     = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                Name     = 'SearchboxTaskbarMode'
                Kind     = 'DWord'
                Expected = 0
                Default  = 2
            }
            @{
                Id       = 'ShowTaskViewButton'
                Label    = 'Task View button hidden'
                Path     = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                Name     = 'ShowTaskViewButton'
                Kind     = 'DWord'
                Expected = 0
                Default  = 1
            }
            @{
                Id       = 'TaskbarDa'
                Label    = 'Widgets button hidden'
                Path     = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                Name     = 'TaskbarDa'
                Kind     = 'DWord'
                Expected = 0
                Default  = 1
                Protected = $true
                ProtectionNote = 'Windows 11 26H2 rejects direct HKCU writes to this value (UnauthorizedAccessException) although the key ACL grants FullControl. No Widgets toggle exists in Settings on this build. The native taskbar is auto-hidden and replaced by Seelen UI 2.8.8, so the value has no visible effect.'
            }
            @{
                Id       = 'HideFileExt'
                Label    = 'File extensions visible'
                Path     = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                Name     = 'HideFileExt'
                Kind     = 'DWord'
                Expected = 0
                Default  = 1
            }
        )
    }

    Apps = @{
        LocalSend = @{
            DisplayName = 'LocalSend'
            Version     = '1.18.2'
            License     = 'Apache-2.0'
            Repository  = 'https://github.com/localsend/localsend'
            ReleaseUrl  = 'https://github.com/localsend/localsend/releases/tag/v1.18.2'
            WingetId    = 'LocalSend.LocalSend'
            InstallMode = 'Manual'
            Assets      = @(
                @{
                    Name   = 'LocalSend-1.18.2-windows-x86-64.exe'
                    Sha256 = '122783e6abb4b0a1f1603d896f46a03aeda3004479ebd3175cab4ddac6b60919'
                    Size   = 19901144
                }
                @{
                    Name   = 'LocalSend-1.18.2-windows-x86-64.zip'
                    Sha256 = '737aab1829d901e1d798cddd1e5fdc06ba9dfcc9ea50cfe3805e047005d5e71a'
                    Size   = 26113764
                }
                @{
                    Name   = 'LocalSend-CLI-1.18.2-windows-x86-64.exe'
                    Sha256 = 'ca0b267e7457324b3664a935de4e4956da701a7fa1045f6f99c72602f7f8dc38'
                    Size   = 9725952
                }
            )
            Network = @{
                DiscoveryPortUdp = 53317
                DiscoveryGroup   = '224.0.0.167'
                RequiresPrivateProfile = $true
            }
        }

        Deskreen = @{
            DisplayName    = 'Deskreen CE'
            Version        = '3.2.16'
            License        = 'AGPL-3.0'
            Repository     = 'https://github.com/pavlobu/deskreen'
            ReleaseUrl     = 'https://github.com/pavlobu/deskreen/releases/tag/v3.2.16'
            InstallMode    = 'Manual'
            RequiresVirtualDisplay = $true
            Assets         = @(
                @{
                    Name   = 'deskreen-ce-3.2.16-x64.exe'
                    Sha256 = 'de6052a0d5dc893e0d16da6a8da82aacae5803602a3efdde50037b536e3213f8'
                    Kind   = 'portable'
                }
                @{
                    Name   = 'deskreen-ce-3.2.16-x64.msi'
                    Sha256 = '9c890626f9a7db5590b9885f862f83f6a8c1526d97ad860e146e8cf7b52ddea6'
                    Kind   = 'installer'
                }
            )
        }
    }

    Gates = @{
        AirPods = @{
            Name                           = 'AirPods Pro 3'
            RequiredPairedNamePattern      = 'AirPods'
            RequiresBluetoothAudioEndpoint = $true
            LiveTest                       = 'stereo-audible-confirmed'
            RecordedAt                     = '2026-10-21'
            Evidence                       = @(
                'Bluetooth radio enumerated as USB\VID_0A12&PID_0001 (CSR-class generic radio, status OK).'
                'Paired device present: AirPods Pro von Jamil, instance BTHENUM\DEV_747786838AC3.'
                'AudioEndpoint present: Kopfhoerer (AirPods Pro ...) and Hands-Free, status OK.'
                'A2DP and AVRCP transports enumerated (BTHENUM 110B/110C/110E).'
                'Service btaudio is not installed; HFP runs through BTHHFENUM, so this is not a blocker.'
                'Endpoints stay enumerated while the AirPods are in the case (Status Unknown); the gate is then WARN, not FAIL.'
                'User confirmed two Windows test tones were clearly audible in the AirPods on 2026-10-21.'
                'Generation (Pro 3) cannot be confirmed from Windows; check the model on an Apple device.'
            )
        }
    }

    DesignInspiration = @{
        Repo    = '43PR/dotfiles'
        License = 'MIT'
        Usage   = 'Design tokens and interaction ideas only. No QML, Lua, shell or package files are copied.'
        Doc     = 'docs/design-43pr.md'
    }

    RepoHygiene = @{
        ForbiddenExtensions = @(
            '.exe', '.msi', '.msix', '.dll', '.sys', '.scr', '.inf',
            '.zip', '.rar', '.7z', '.msstyles', '.theme', '.rmskin'
        )
    }
}
