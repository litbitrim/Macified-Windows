# Prüfen und visuell abnehmen

Zwei Ebenen: **automatisch** (misst Registry, Apps, Hardware, Repo) und
**visuell** (nur am PC zu beurteilen). Der Verifier ist strikt read-only.

## 1. Automatische Prüfung

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Test-MacifiedState.ps1
```

Exit-Codes: `0` = kein FAIL, `1` = mindestens ein FAIL, `2` = Konfiguration
nicht ladbar. WARN blockiert nicht, ist aber dokumentationspflichtig.

Maschinenlesbar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Test-MacifiedState.ps1 -Json
```

### Erwartung nach dem angewendeten Baseline (Ist-Zustand 2026-10-21)

| Bereich | Erwartung |
| --- | --- |
| OS | PASS (Windows 11 Pro 26H2 26300.9711) |
| Look | 7 PASS, 1 WARN (`TaskbarDa` OS-geschützt) |
| Akzent | WARN (`#0078D4` statt `#007AFF`, manuell) |
| Wallpaper | WARN (eigenes Macified-Glass-Bild, kein Referenzhash) |
| LocalSend | PASS 1.18.2 |
| Firewall | WARN (2 Regeln erlauben Public) |
| Netzwerkprofil | WARN (`Netzwerk=Public`) |
| Deskreen / virtueller Monitor | portable App läuft; Verifier meldet mangels Uninstall-Eintrag WARN; virtueller Monitor fehlt |
| AirPods-Gate | PASS `ready` bei Verbindung, sonst WARN `paired, not connected` |
| Repo | PASS (keine Binärdateien, NOTICE/LICENSE/Doku vorhanden) |

Gesamt: **Exit 0** ist erreichbar; FAIL gibt es nach dem Baseline nicht mehr.
Offene WARN sind dokumentiert: Akzent, Wallpaper, Firewall/Netzwerk, optionale
Deskreen-Bausteine, AirPods-Verbindung und der OS-geschützte Widgets-Wert.

> **Taskleisten-Umgebung:** Die native Taskleiste ist auto-hidden und wird von
> **Seelen UI 2.8.8** (MSIX) ersetzt. `TaskbarAl`, `SearchboxTaskbarMode` und
> `TaskbarDa` wirken daher nicht sichtbar. Seelen UI ist nicht Teil dieses
> Pakets und wird nicht verändert.

### Guardrails, die der Verifier prüft

- keine `.exe/.msi/.zip/.rar/.7z/.msstyles/.theme/.rmskin` im Fork
- `NOTICE.md`, `macified/LICENSE`, `docs/design-43pr.md` vorhanden
- Look-Werte ausschließlich unter `HKCU` (Apply-Skript erzwingt das)

### Tests der Kernlogik

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\tests\run-tests.ps1
```

Erwartet: alle Tests grün, `FailedCount = 0`. Geprüft werden Farbkonvertierung,
Default-Behandlung, Gate-Logik, Repo-Hygiene und die Abwesenheit von
Schreib-/Start-Befehlen in Verifier und Apply-Skript.

## 2. Visuelle Abnahme am PC

Jede Zeile ist eine Sichtprüfung. „OK“ erst setzen, wenn das beobachtete
Ergebnis exakt stimmt.

| ID | Prüfung | Erwartetes Ergebnis | OK |
| --- | --- | --- | --- |
| V1 | Einstellungen öffnen | Fenster und Inhalte dunkel, keine weißen Flächen | ☐ |
| V2 | Explorer öffnen | dunkles Fenster, Titelleiste dunkel | ☐ |
| V3 | Startmenü öffnen | halbtransparent/dunkel, Akzent nur an Fokus/Controls | ☐ |
| V4 | Native Taskleiste ansehen | App-Symbole mittig – **N/A**, solange Seelen UI läuft | ☐ |
| V5 | Native Taskleiste ansehen | **kein** Suchfeld – **N/A**, solange Seelen UI läuft | ☐ |
| V6 | Native Taskleiste ansehen | **kein** Task-View-Symbol – **N/A**, solange Seelen UI läuft | ☐ |
| V7 | Native Taskleiste ansehen | **kein** Widgets-Feld – **N/A**, solange Seelen UI läuft | ☐ |
| V8 | Explorer im Ordner `macified/.artifacts/visual-fixture` | `abnahme.txt` statt `abnahme`; Beleg: [`compare-file-extensions.png`](../.artifacts/visual-acceptance/compare-file-extensions.png) | ☐ |
| V9 | Einstellungen → Personalisierung → Farben | Akzent `#007AFF`; „Akzentfarbe auf Start und Taskleiste“ aus; Transparenz an | ☐ |
| V10 | Desktop-Hintergrund | eigenes Bild, Füllmodus „Ausfüllen“, keine Apple-Datei | ☐ |
| V11 | LocalSend starten | Gerätename sichtbar; zweites Gerät im selben WLAN findet den PC | ☐ |
| V12 | Datei in beide Richtungen senden | Ankunft, Größe und Inhalt identisch | ☐ |
| V13 | AirPods einsetzen, Ausgabe wählen | „Kopfhörer (AirPods Pro …)“ aktiv, Stereo hörbar (links/rechts) | ☐ |
| V14 | Mikrofon-Test (Teams/Sprachaufnahme) | Mikrofon funktioniert; Umschaltung auf HFP mono ist akzeptiert | ☐ |
| V15 | Deskreen (falls genutzt) | Viewer im Browser zeigt den gewählten Bildschirm; „Freigabe beenden“ trennt sofort | ☐ |
| V16 | Deskreen erweitert (falls genutzt) | zweiter Monitor sichtbar und als „Erweitern“ nutzbar | ☐ |
| V17 | Undo-Dry-Run | listet 8 Werte, schreibt nichts, Exit 0 | ☐ |
| V18 | Dashboard öffnen (`Start-MacifiedDashboard.ps1`) | vier Karten gefüllt, Live-Punkt grün, keine externen Requests | ☐ |

### Hilfreiche Kontrollbefehle

```powershell
# aktuelle Look-Werte kompakt
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Test-MacifiedState.ps1

# AirPods-Endpunkte
Get-PnpDevice -Class AudioEndpoint | Where-Object FriendlyName -like '*AirPods*' |
  Select-Object Status, FriendlyName

# LocalSend-Firewall
Get-NetFirewallRule -DisplayName '*LocalSend*' |
  Select-Object DisplayName, Direction, Action, Profile, Enabled

# Display-Adapter (virtueller Monitor?)
Get-PnpDevice -Class Display | Select-Object Status, FriendlyName
```

## 3. Status-Dashboard

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Start-MacifiedDashboard.ps1
# http://127.0.0.1:5555/
```

Read-only-Gegenprobe: Die Karten müssen die Werte des Verifiers spiegeln.
LocalSend `Bereit` bei Listener, AirPods `Gekoppelt` im Case, Deskreen
`Nicht installiert`, Baseline `7/8 konform`. Der Live-Punkt darf nur grün sein,
wenn `/api/status` mit 200 antwortet. Details: [`dashboard.md`](dashboard.md).

## 4. Abnahmeprotokoll

| Feld | Eintrag |
| --- | --- |
| Datum/Uhrzeit | |
| Build | 26300.9711 |
| Verifier-Summary | PASS / WARN / FAIL |
| Getestete Punkte | V1–V17 |
| Abweichungen | |
| Rollback getestet | ja/nein |
| Unterschrift/Initialen | |

Die drei wichtigsten Fehlerbilder und ihre Ursache:

1. **Taskleiste bleibt links** → `TaskbarAl` fehlt oder ist `0`; Verifier zeigt
   `Taskbar icons centered` FAIL. Abmelden/Anmelden, dann erneut prüfen.
2. **Suche/Widgets weiter sichtbar** → solange Seelen UI läuft, ist die native
   Taskleiste verborgen; das ist kein Fehler. `TaskbarDa` lässt sich auf 26H2
   nicht per Registry schreiben und hat keinen Settings-Schalter.
3. **AirPods-Gate FAIL** → Gerät nicht gekoppelt; bei `WARN` sind die AirPods
   nur im Case. Ein fehlender `btaudio`-Dienst ist **kein** Fehler.
