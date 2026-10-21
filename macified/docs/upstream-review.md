# Prüfung des Upstreams und des Ist-Zustands

Stand: 2026-10-21. Geprüft wurde der Fork `litbitrim/Macified-Windows`
(Basis `Runixe786/Macified-Windows`, Branch `main`, letzter Upstream-Commit
`a7680dd`).

## 1. Repository-Inhalt

```
README.md                       # Anleitung des Upstreams, CRLF, ~11 KB
Assets/563CA2A9-….svg           # 21 KB, Vektor
Assets/5D4A5C40-….svg           # 22 KB, Vektor
Assets/7D9558C9-….png           # 144 KB, 1563×1563 RGBA
Assets/B8CA423C-….svg           # 21 KB, Vektor
Assets/EBAE944E-….svg           # 21 KB, Vektor
Assets/IMG_6951.png             # 436 KB, 1387×400 RGBA
Assets/test.png                 # 2 Byte (0x0D 0x0A) – keine gültige PNG-Datei
```

Es gibt **keine** ausführbaren Dateien, Themes oder Skripte im Git. Die Assets
sind reine Bilder ohne Lizenzangabe. `Assets/test.png` ist trotz Endung keine
Bilddatei, sondern ein leerer Platzhalter; er bleibt unverändert und wird nicht
verwendet.

## 2. Was das README verspricht

Das README beschreibt einen mehrstufigen Eingriff in Windows:

1. `ThemePatcher` patcht `Themeui` und `uxinit`, danach Neustart.
2. Theme-Ordner nach `C:\Windows\Resources\Themes` kopieren.
3. Rainmeter-Widgets installieren.
4. Ein Dock-Programm (`dock_64.exe`) starten und ein Layout-Backup laden.
5. System-Icons mit 7tsp patchen, inklusive vorbereiteter Archivdateien.
6. ExplorerBlurMica für Blur-Effekte, Cursor-Paket per `install.inf`.
7. Optional StartAllBack, OldNewExplorer, Leftsider.

Zusätzlich verweist es auf ein Release `V1.0.0` mit 13 Fremdpaketen
(`Macified.Windows.zip`, `Themes_MacifiedWindows.zip`, `7tsp_MacifiedWindows.zip`,
`ThemePatcher_MacifiedWindows.exe`, `Dock_MacifiedWindows.rar`,
`Rainmeter_MacifiedWindows.exe`, `StartAllBack_MacifiedWindows.exe`,
`Widgets_MacifiedWindows.rmskin`, Cursor-/Wallpaper-Archive u. a.).

## 3. Bewertung

| Punkt | Bewertung | Konsequenz |
| --- | --- | --- |
| Lizenz | GitHub-API `license: null`, keine Lizenzdatei | Keine Übernahme, keine Weitergabe, keine Ableitung |
| Archivstatus | seit 2025-07-17 archiviert | Keine Upstream-Fixes oder Sicherheitsupdates zu erwarten |
| Binärpakete | nicht im Git, nur im Release; Herkunft laut Release-Notes „found on internet“ | Nicht ausführbar, nicht prüfbar, nicht vertrauenswürdig |
| Systempatch `uxinit`/`Themeui` | Eingriff in Signatur-/Systemintegrität | Abgelehnt: Risiko, Updates, Support, Sicherheit |
| 7tsp / Icon-Patch | patcht Systemressourcen | Abgelehnt |
| StartAllBack / ExplorerBlurMica | Drittanbieter mit eigener Lizenz, teils kostenpflichtig | Nicht Teil der Baseline; nur bewusste Einzelentscheidung des Nutzers |
| Dock/Rainmeter | zusätzliche Fremdprogramme, hohe Angriffsfläche | Nicht Teil der Baseline |
| Assets | keine Lizenz | Bleiben unverändert, werden nicht neu veröffentlicht |
| `test.png` | defekte Datei (2 Byte) | Dokumentiert, nicht verwendet |

## 4. Eigene, minimale Baseline

Statt Systemdateien zu patchen, nutzt dieses Paket ausschließlich dokumentierte
Benutzereinstellungen unter `HKCU` und ergänzt bewusst nur das, was Windows 11
von sich aus kann:

- Dark Mode, Transparenz, zentrierte Taskleiste, reduzierte Taskleisten-Symbole
- sichtbare Dateiendungen (auch sicherheitsrelevant)
- Akzentfarbe und Wallpaper als manuelle Schritte

Damit ist der Look **nicht identisch** mit den Upstream-Screenshots. Die Lücke
ist beabsichtigt und wird in [`verify.md`](verify.md) offen benannt: kein
mitgeliefertes Dock, keine macOS-Cursor, keine System-Icons, kein Blur in
Explorer-Fenstern, kein echter macOS-Menüleisten-Ersatz.

## 5. Ist-Zustand des PCs (read-only erhoben)

| Merkmal | Wert |
| --- | --- |
| OS | Windows 11 Pro, 26H2, Build 26300.9711, 64-Bit |
| PowerShell | 5.1.26100.9711 |
| winget | vorhanden |
| Pester | 3.4.0 |
| GPU | AMD Radeon RX 6950 XT (einziger Display-Adapter) |
| Bluetooth | `USB\VID_0A12&PID_0001`, Generic Bluetooth Radio, Status OK |
| AirPods | „AirPods Pro von Jamil“, gekoppelt; A2DP/AVRCP/HFP-Endpunkte aktiv |
| `btaudio` | nicht installiert (für HFP nicht erforderlich) |
| LocalSend | 1.18.2 installiert und laufend, `C:\Program Files\LocalSend` |
| LocalSend-Firewall | 2 eingehende Allow-Regeln, Profil `Private, Public` |
| Seelen UI | 2.8.8 als MSIX aus `WindowsApps`, Prozess `seelen-ui`, Fenster „Dock/Taskbar“ |
| Native Taskleiste | `Shell_TrayWnd` vorhanden, aber **nicht sichtbar** (auto-hidden, von Seelen UI ersetzt) |
| Netzwerkprofil | Ethernet `Netzwerk` = `Public`, Tailscale = `Private` |
| Deskreen | nicht installiert, kein virtueller Monitor |
| Look-Werte (nach Baseline) | Dark Mode an, Transparenz an, Taskleiste zentriert (Default), Suche aus, Task-View aus, Dateiendungen sichtbar, Widgets Default (OS-geschützt) |
