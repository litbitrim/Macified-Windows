# Macified Windows 11 26H2 – sichere PC-Integration

Ziel: ein **nachvollziehbarer, umkehrbarer** Mac-artiger Look auf Windows 11 Pro
26H2 (Build 26300.9711) plus die saubere Vorbereitung von LocalSend, AirPods Pro 3
und DisplayShare. Kein System-Patching, keine Fremdbinärdateien, keine
Weitergabe von Inhalten ohne Lizenz.

Das Original `Runixe786/Macified-Windows` ist archiviert und hat **keine
Lizenz**. Deshalb ist dieses Paket eine eigenständige Minimallösung und keine
Weiterverwendung des Upstreams. Details: [`../NOTICE.md`](../NOTICE.md).

## Status am 2026-10-21 (gemessen, nicht angenommen)

| Baustein | Zustand | Beleg |
| --- | --- | --- |
| Look-Baseline (8 HKCU-Werte) | **angewendet**: 7/8 entsprechen dem Soll (2 geschrieben, 5 bereits konform); `TaskbarDa` ist OS-geschützt (WARN) | `Test-MacifiedState.ps1`, [`config/macified.psd1`](config/macified.psd1) |
| Taskleisten-Umgebung | **Seelen UI 2.8.8** ersetzt die native Taskleiste; `Shell_TrayWnd` ist auto-hidden | [`docs/verify.md`](docs/verify.md) |
| Akzentfarbe | manuell offen, aktuell `#0078D4`, Soll `#007AFF` | [`docs/setup.md`](docs/setup.md) |
| Wallpaper | eigenes Macified-Glass-Bild live gesetzt; kein Referenzhash konfiguriert | [`docs/setup.md`](docs/setup.md) |
| LocalSend | **1.18.2 installiert** (`C:\Program Files\LocalSend`); Firewall-Regeln erlauben auch `Public`; Netzwerkprofil `Public`; keine App-Settings vorhanden | [`docs/apps/localsend.md`](docs/apps/localsend.md) |
| AirPods Pro 3 | **gekoppelt**; zwei Windows-Testtöne in den AirPods hörbar bestätigt; Mikrofon und Generation offen | [`docs/apps/airpods-pro-3.md`](docs/apps/airpods-pro-3.md) |
| Deskreen CE 3.2.16 | portable Windows-App läuft; Viewer-URL antwortet HTTP 200; Mac-Bildtest und virtueller Monitor offen | [`docs/apps/deskreen.md`](docs/apps/deskreen.md) |
| 43PR/dotfiles | nur Design-Inspiration dokumentiert, kein Code übernommen | [`docs/design-43pr.md`](docs/design-43pr.md) |
| Status-Dashboard | lokal, read-only, nur Loopback; LocalSend, AirPods, Deskreen und Baseline in einer Ansicht | [`docs/dashboard.md`](docs/dashboard.md) |
| Repo-Hygiene | 0 Binärdateien im Fork | Verifier, Abschnitt `Repo` |

Der frühere Eindruck „Bluetooth-Hardware nicht erkannt“ ist damit überholt:
Es ist ein generischer CSR-Radio (`USB\VID_0A12&PID_0001`) verbaut, über den die
AirPods gekoppelt sind und Audioendpunkte bereitstellen. Der Dienst `btaudio`
fehlt, was für HFP über `BTHHFENUM` normal ist. Im Case sind die Endpunkte
`Unknown`; dann meldet das Gate `WARN` statt `FAIL`. Der Nutzer hat die
Windows-Testtöne gehört; Klang und Mikrofon bleiben technisch nicht automatisch prüfbar.

## Schnellstart

Alle Befehle ab dem Repo-Wurzelverzeichnis, PowerShell 5.1:

```powershell
# 1. Ist-Zustand lesen (keine Änderung, Exit 1 = offene Punkte)
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Test-MacifiedState.ps1

# 2. Änderungen nur anzeigen (Dry-Run, Standard)
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Apply-MacifiedLook.ps1

# 3. Bewusst anwenden (schreibt offene Werte, sichert alle 8; TaskbarDa bleibt OS-geschützt)
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Apply-MacifiedLook.ps1 -Apply

# 4. Rückgängig (Dry-Run zuerst)
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Undo-MacifiedLook.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Undo-MacifiedLook.ps1 -Apply

# 5. Status-Dashboard lesen (Ctrl+C beendet den Server)
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Start-MacifiedDashboard.ps1
# danach http://127.0.0.1:5555/ öffnen
```

Schritt 3 wurde am 2026-10-21 bewusst ausgeführt: zwei Werte wurden geschrieben,
fünf waren bereits konform, `TaskbarDa` blieb OS-geschützt. Das Backup liegt unter
`%LOCALAPPDATA%\MacifiedWindows\backups\`. Schritt 3 bleibt der einzige Schritt,
der den Rechner verändert.

## Was die Baseline umfasst

Ausschließlich benutzerspezifische, umkehrbare Einstellungen:

- dunkles Design für Apps und Windows-Oberflächen
- Transparenzeffekte an
- Taskleiste zentriert
- Taskleisten-Suche und Task-View aus
- Dateiendungen im Explorer sichtbar

`TaskbarDa` (Widgets) wird von Windows 11 26H2 trotz Vollzugriff-ACL nicht
geschrieben; der Wert bleibt auf dem Default und wird vom Verifier als WARN
geführt. Die native Taskleiste ist zudem auto-hidden und wird von Seelen UI
2.8.8 ersetzt, daher sind Taskleisten-Änderungen derzeit nicht sichtbar.
Akzentfarbe und Wallpaper bleiben manuell: Registry-Schreiben erzeugt keine
verlässliche Akzentpalette, und Apple-Wallpaper sind nicht lizenzierbar.

## Was hier absichtlich **nicht** passiert

- keine Theme-Patches an `uxinit`/`Themeui`, kein 7tsp, kein StartAllBack,
  kein ExplorerBlurMica, keine Cursor-/Icon-Pakete aus dem Upstream
- keine EXE/MSI/ZIP/RAR/RMSKIN im Git
- keine Installation, kein Start und kein Download durch Skripte
- keine Arch-/Hyprland-/Quickshell-Dateien aus 43PR/dotfiles
- keine Änderungen an `HKLM`, Systemdateien, Diensten oder Richtlinien

## Dateien

| Pfad | Zweck |
| --- | --- |
| [`docs/upstream-review.md`](docs/upstream-review.md) | Prüfung von Upstream-README, Assets und Release-Paketen |
| [`docs/setup.md`](docs/setup.md) | kleinste vollständige Anpassung, Schritt für Schritt |
| [`docs/rollback.md`](docs/rollback.md) | Undo, manuelle Rücknahme, App-Entfernung |
| [`docs/verify.md`](docs/verify.md) | automatische Prüfung und visuelle Abnahme am PC |
| [`docs/dashboard.md`](docs/dashboard.md) | lokales read-only Status-Dashboard: Start, Datenquellen, Grenzen |
| [`docs/apps/localsend.md`](docs/apps/localsend.md) | LocalSend 1.18.2 einrichten und prüfen |
| [`docs/apps/airpods-pro-3.md`](docs/apps/airpods-pro-3.md) | AirPods Pro 3: Realität unter Windows, Gate, Test |
| [`docs/apps/deskreen.md`](docs/apps/deskreen.md) | DisplayShare mit Deskreen CE 3.2.16 |
| [`docs/design-43pr.md`](docs/design-43pr.md) | optionale MIT-Design-Inspiration, portierbare Ideen |
| [`config/macified.psd1`](config/macified.psd1) | Soll-Zustand, Versionspins, Prüfsummen, Gates |
| [`scripts/Test-MacifiedState.ps1`](scripts/Test-MacifiedState.ps1) | read-only Verifier (PASS/WARN/FAIL) |
| [`scripts/Apply-MacifiedLook.ps1`](scripts/Apply-MacifiedLook.ps1) | Dry-Run-Default, `-Apply` schreibt HKCU |
| [`scripts/Undo-MacifiedLook.ps1`](scripts/Undo-MacifiedLook.ps1) | Backup zurücknehmen |
| [`scripts/Test-DownloadIntegrity.ps1`](scripts/Test-DownloadIntegrity.ps1) | Hash/Signatur manuell geladener Dateien |
| [`scripts/Macified.Dashboard.psm1`](scripts/Macified.Dashboard.psm1) | read-only Collector für den Status-Snapshot |
| [`scripts/Start-MacifiedDashboard.ps1`](scripts/Start-MacifiedDashboard.ps1) | Loopback-Server, GET-only, keine Schreibzugriffe |
| [`dashboard/`](dashboard/) | statische Oberfläche (HTML/CSS/JS, keine externen Assets) |
| [`tests/`](tests/) | Pester-Tests für Kernlogik und Guardrails |

## Lizenz

Eigene Beiträge: MIT, siehe [`LICENSE`](LICENSE). Upstream-Inhalte: keine Lizenz,
nicht weiterverwenden. Drittkomponenten: siehe [`../NOTICE.md`](../NOTICE.md).
