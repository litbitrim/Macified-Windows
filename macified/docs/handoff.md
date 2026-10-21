# Handoff – Macified Windows 11 26H2

Stand: 2026-10-21 · Branch: `feat/macified-look-26h2` · **nicht committet, nicht gepusht**

Nachtrag der Windows-Lead-Session: Zwei Windows-Testtöne waren in den AirPods hörbar; das eigene Macified-Glass-Wallpaper ist gesetzt; Deskreen CE 3.2.16 läuft portabel und die Viewer-Seite antwortet HTTP 200. Die folgenden Messwerte stammen aus dem früheren Freebuff-Durchlauf und bleiben als Zeitpunktbefund erhalten. Ein Mac-zu-Windows-Bildtest und das AirPods-Mikrofon stehen noch aus.

## Ergebnis

Die Look-Baseline ist **angewendet**: 7 von 8 Werten entsprechen dem Soll;
 geschrieben wurden 2 (`SearchboxTaskbarMode`, `HideFileExt`), 5 waren bereits
konform. `TaskbarDa` (Widgets) verweigert Windows 11 26H2 trotz Vollzugriff-ACL;
der Wert bleibt beim Default und ist als WARN dokumentiert. Der sichtbare Beleg
(Dateiendungen) liegt als Vorher-/Nachher-Screenshot vor.

Zusätzlich gibt es ein **lokales read-only Status-Dashboard** für LocalSend,
AirPods, Deskreen und die Baseline. Es bindet nur an `127.0.0.1`, beantwortet
nur `GET` und schreibt nichts. Start: `Start-MacifiedDashboard.ps1`, danach
`http://127.0.0.1:5555/`.

## Angewendete Werte

| Wert | Soll | Ist | Status |
| --- | --- | --- | --- |
| `AppsUseLightTheme` | 0 | 0 | PASS |
| `SystemUsesLightTheme` | 0 | 0 | PASS |
| `EnableTransparency` | 1 | 1 | PASS |
| `TaskbarAl` | 1 | fehlt → Default 1 | PASS |
| `SearchboxTaskbarMode` | 0 | 0 | PASS |
| `ShowTaskViewButton` | 0 | 0 | PASS |
| `TaskbarDa` | 0 | fehlt → Default 1 | **WARN, OS-geschützt** |
| `HideFileExt` | 0 | 0 | PASS |

Backup: `%LOCALAPPDATA%\MacifiedWindows\backups\look-20261021-130855.json`
(alle 8 Werte, inklusive „war nicht gesetzt“).

## Umgebung, die den Look dominiert

- **Seelen UI 2.8.8** läuft als MSIX aus `WindowsApps` und stellt „Dock/Taskbar“.
- Die native Taskleiste ist **auto-hidden** (`Shell_TrayWnd` nicht sichtbar).
- Deshalb sind Taskleisten-Werte derzeit nicht visuell prüfbar; sie gelten,
  sobald die native Leiste wieder sichtbar wäre.
- Seelen UI ist nicht Teil dieses Pakets und wurde nicht verändert.

## Screenshots (lokal, nicht im Git)

Pfad: `macified/.artifacts/visual-acceptance/` (per `.gitignore` ausgeschlossen)

| Datei | Beleg |
| --- | --- |
| `before-explorer-print.png` | `abnahme` (Endung ausgeblendet) |
| `after-explorer-print.png` | `abnahme.txt` (Endung sichtbar) |
| `compare-file-extensions.png` | beschriftete Gegenüberstellung |
| `dashboard-desktop-v2.png` | Dashboard 1440×900, alle vier Karten gefüllt |
| `dashboard-mobile.png` | Dashboard 390×844, gestapelte Karten |

Windows-OCR bestätigt die beiden Dateinamen in den Aufnahmen. Die Bilder zeigen
nur das Explorer-Fenster, keine anderen Desktop-Inhalte.

## Diff

| Bereich | Umfang |
| --- | --- |
| `README.md` | +2 Zeilen Fork-/Lizenzhinweis |
| `.gitignore` | neu: `.freebuff/`, Binärpakete, `.artifacts/` |
| `NOTICE.md` | neu: Upstream-Archiv, fehlende Lizenz, Drittlizenzen |
| `macified/` | neu: 25 Dateien, ca. 4.460 Zeilen (Doku, Config, 7 Skripte/Module, Dashboard, Tests) |

Keine `Assets/`-Datei verändert, keine Binärdatei hinzugefügt.

## Tests

| Prüfung | Ergebnis |
| --- | --- |
| Pester-Suite | **38/38 grün**, Exit 0 |
| Dashboard HTTP | `/` 200, CSS/JS 200 mit korrektem Typ, `/api/status` 200, 404 und 405 geprüft |
| Dashboard CSP | `default-src 'none'`, `frame-ancestors 'none'`, nur `'self'` |
| Dashboard Snapshot | LocalSend `ready`, AirPods `paired`, Deskreen `missing`, Baseline 7/8 |
| Verifier | **13 PASS, 8 WARN, 0 FAIL**, Exit 0 |
| Apply Dry-Run | 0 schreibbar, 1 protected/manual; nichts geschrieben, Exit 0 |
| Undo Dry-Run (Fixture) | plant Rücknahme, schreibt nichts, Exit 0 |
| Undo-Guard | HKLM-Backup wird abgelehnt |
| Download-Integrität | Hash-Treffer Exit 0, Mismatch Exit 1 |
| OCR | `abnahme` vorher, `abnahme.txt` nachher |

Die 8 WARN: `TaskbarDa` (OS-geschützt), Akzent, Wallpaper, LocalSend-Firewall,
Netzwerkprofil, virtueller Monitor, Deskreen nicht installiert, AirPods im Case.

## Risiken

| Risiko | Schwere | Umgang |
| --- | --- | --- |
| Upstream ohne Lizenz | hoch | nichts übernommen/weitergegeben; `NOTICE.md` |
| `TaskbarDa` nicht schreibbar | mittel | Wert bleibt Default; kein Bypass, kein ACL-Trick |
| Seelen UI dominiert Taskleiste | mittel | Taskleisten-Änderungen aktuell unsichtbar; nicht angefasst |
| LocalSend im Public-Profil | mittel | manuell auf Private begrenzen |
| Generisches CSR-Bluetooth-Radio | mittel | Aussetzer möglich; USB-2-Port/Adapter testen |
| AirPods-Generation unbestätigt | niedrig | Modellnummer auf Apple-Gerät/Case prüfen |
| Deskreen: Electron 37 EOL | mittel | nur manuell, kein Dauerbetrieb, kein Internet-Expose |
| Deskreen: Bildschirminhalt im LAN | mittel | nur vertrauenswürdiges Netz, danach „Stop sharing“ |
| Feature-Updates setzen HKCU zurück | niedrig | Verifier erneut ausführen |

## Offene Schritte (bewusst manuell)

1. Akzent `#007AFF` setzen, „Akzentfarbe auf Start und Taskleiste“ aus.
2. Eigenes Wallpaper setzen.
3. LocalSend: Netzwerkprofil Privat, Firewall nur Privat, Gerät testen.
4. AirPods: Stereo und Mikrofon testen, Generation prüfen.
5. Optional Deskreen: Hash prüfen, portabel starten, Freigabe testen.
6. Visuelle Abnahme V1–V17, insbesondere V8 mit dem Screenshot-Beleg.
7. Dashboard starten, Karten gegen die echten Apps prüfen; AirPods zum Testen einsetzen.
8. `TaskbarDa`: kein manueller Weg auf dieser Build; als WARN akzeptieren.

## Nicht getan

- keine App-Installation, kein Start einer heruntergeladenen EXE/MSI
- keine Seelen-UI-Änderung, kein Deaktivieren der Taskleisten-Ersetzung
- kein Commit, kein Push, kein PR
- kein dauerhaft installierter Dashboard-Dienst; der Server läuft nur im Vordergrund und endet mit `Ctrl+C`
- keine Brain-Queue-Änderung
- keine Systemdatei- oder HKLM-Änderung
