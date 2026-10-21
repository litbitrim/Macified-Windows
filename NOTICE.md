# Herkunft, Lizenzen und Grenzen dieses Forks

Dieses Repository ist ein **öffentlicher Fork im GitHub-Konto litbitrim** von
[Runixe786/Macified-Windows](https://github.com/Runixe786/Macified-Windows)
(Fork: [litbitrim/Macified-Windows](https://github.com/litbitrim/Macified-Windows)).
Es ist kein offizielles Projekt und steht in keiner Verbindung zu Apple.

## 1. Befund zum Original

| Punkt | Befund | Beleg |
| --- | --- | --- |
| Status | Archiviert, nur noch lesbar | GitHub-API `archived: true`; Banner „archived by the owner on Jul 17, 2025“ |
| Lizenz | **Keine Lizenz erteilt** | GitHub-API `license: null`; im Dateibaum liegt keine `LICENSE`, `COPYING` oder Lizenzangabe |
| Inhalt des Repos | Nur `README.md` und `Assets/` (7 Bilddateien) | Git-Tree des Upstreams |
| Release `V1.0.0` | 13 Fremdpakete (Themes, ThemePatcher, 7tsp, Dock/RAR, Rainmeter, StartAllBack, ExplorerBlurMica, Cursor, Wallpaper u. a.) | Release-Seite; im Git selbst **nicht** enthalten |
| README | verweist auf diese Binärpakete und auf das Patchen von `Themeui`/`uxinit` | Upstream-README, Abschnitte „Themes“ und „System & dock icons“ |
| Credits | „packages … arent developed by me but only found on internet“ | Release-Notes `V1.0.0` |

Ohne Lizenz gilt: Alle Rechte liegen bei den jeweiligen Rechteinhabern. Es wird
**keine** Erlaubnis zur Vervielfältigung, Weitergabe oder Bearbeitung erteilt.
Deshalb werden die Upstream-Dateien weder verändert noch weiterverbreitet und
es werden **keine** Binärpakete, Themes, Cursor, Skins, Skripte oder Wallpaper
aus dem Upstream übernommen. Die vorhandenen `README.md` und `Assets/` bleiben
unverändert als Fork-Historie liegen; sie sind nicht Teil der hier erteilten
Lizenz. Da der GitHub-Fork öffentlich ist, erteilt dieses Dokument keine Rechte
an diesen unveränderten Upstream-Dateien; für eine Weitergabe außerhalb der
GitHub-Fork-Beziehung sind die Rechte separat zu klären.

## 2. Umfang der eigenen Beiträge

Alle Dateien unter [`macified/`](macified/) sowie diese `NOTICE.md` sind
eigenständig erstellt. Sie stehen unter der MIT-Lizenz, siehe
[`macified/LICENSE`](macified/LICENSE). Diese Lizenz gilt **nicht** für
`README.md`, `Assets/` oder sonstige Upstream-Inhalte.

## 3. Drittkomponenten (nicht mitgeliefert)

| Komponente | Version | Lizenz | Verwendung hier |
| --- | --- | --- | --- |
| [LocalSend](https://github.com/localsend/localsend) | 1.18.2 | Apache-2.0 | Nur Dokumentation, Prüfsummen und Verifikation. Kein Installer im Repo. |
| [Deskreen CE](https://github.com/pavlobu/deskreen) | 3.2.16 | AGPL-3.0 | Nur Dokumentation, Prüfsummen und Verifikation. Kein Installer, keine Weitergabe, kein Hosting einer abgewandelten Fassung. |
| [43PR/dotfiles](https://github.com/43PR/dotfiles) | Stand `main`, 2026-10-21 | MIT | Nur Design-Ideen und Zahlenwerte mit Quellenangabe. Kein QML-, Lua- oder Shell-Code übernommen. |
| Seelen UI | 2.8.8 (lokal installiert) | Drittanbieter, nicht geprüft | Nicht Teil dieses Repos, nicht verändert, nicht weitergegeben. Es ersetzt lokal die native Taskleiste. |
| Windows 11 | 26H2, Build 26300.9711 | Microsoft-EULA | Nur dokumentierte, umkehrbare Benutzereinstellungen. |
| Apple AirPods / macOS | – | Apple-EULA, Marken | Nur Kompatibilitätsdokumentation. Keine Apple-Dateien, keine Wallpaper, keine Schriftarten. |

„Apple“, „AirPods“, „macOS“ und zugehörige Bezeichnungen sind Marken von Apple
Inc. Dieses Projekt ist weder mit Apple verbunden noch von Apple unterstützt.

## 4. Sicherheits- und Prüfgrundsätze

- Keine Systemdateien, keine Theme-Patches, kein Deaktivieren von Signaturprüfungen.
- Look-Anpassung ausschließlich unter `HKCU` mit Sicherung und Undo.
- Keine automatischen Downloads, Installationen oder Programmstarts.
- Keine Binärdateien im Git; `macified/scripts/Test-MacifiedState.ps1` prüft das.
- Prüfsummen stammen aus den GitHub-Release-Metadaten vom 2026-10-21 und sind
  nur dann belastbar, wenn sie vor dem Ausführen erneut geprüft werden.

Dieses Dokument ist keine Rechtsberatung. Wer den Fork öffentlich teilt, muss
die Rechte an `README.md` und `Assets/` selbst klären.
