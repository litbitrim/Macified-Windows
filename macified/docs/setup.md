# Setup – kleinste vollständige Anpassung

Diese Anleitung ändert **nur** Benutzereinstellungen (`HKCU`) und dokumentiert
die manuellen Schritte. Sie wurde in dieser Session nicht ausgeführt. Jeder
Schritt ist umkehrbar, siehe [`rollback.md`](rollback.md).

## 0. Voraussetzungen und Baseline

- Windows 11 Pro 26H2, Build 26300.9711 (verifiziertes Profil)
- PowerShell 5.1, keine Adminrechte für die Look-Schritte nötig
- Ein eigenes oder frei lizenziertes Wallpaper-Bild

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Test-MacifiedState.ps1
```

Vor dem Setup ist ein Exit-Code **1** normal: Suche, Widgets und Dateiendungen
weichen ab, Akzent und Wallpaper sind manuell. Wichtig ist, dass der Abschnitt
`Repo` PASS zeigt und der AirPods-Gate-Status `ready` ist.

## 1. Änderungen ansehen (Dry-Run)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Apply-MacifiedLook.ps1
```

Erwartet: `2 value(s) would be written, 1 protected/manual` (Suche,
Dateiendungen; Widgets ist OS-geschützt). Es wird nichts geschrieben. Der
Befehl endet mit „No registry value was modified.“

## 2. Look anwenden (bewusster Opt-in)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Apply-MacifiedLook.ps1 -Apply
```

Das Skript:

- prüft, dass jeder Pfad unter `HKCU\Software\…` liegt und keine Policies berührt,
- sichert **alle acht** Werte inklusive „war nicht gesetzt“ nach
  `%LOCALAPPDATA%\MacifiedWindows\backups\look-<Zeitstempel>.json`,
- schreibt nur die schreibbaren abweichenden Werte,
- überspringt `TaskbarDa` bewusst, weil Windows 11 26H2 direkte Schreibzugriffe
  mit `UnauthorizedAccessException` ablehnt (die ACL erlaubt Vollzugriff – die
  Sperre sitzt tiefer), und meldet `MANUAL`,
- merkt den Backup-Pfad in `%LOCALAPPDATA%\MacifiedWindows\last-apply.json`,
- speichert dort die SHA-256-Prüfsummen von Backup und Konfiguration für den
  späteren Integritätscheck,
- endet mit **Exit 2**, solange ein geschützter Wert offen ist.

Erwartete Ausgabe: `WROTE …` für zwei Werte, `MANUAL …` für Widgets, `Backup: …`.

> **Taskleiste:** Die native Taskleiste ist auto-hidden und wird von **Seelen UI
> 2.8.8** ersetzt. Die Werte gelten weiterhin, sind aber aktuell nicht sichtbar.
> `TaskbarDa` hat in dieser Build auch keinen Widgets-Schalter in den
> Einstellungen; es bleibt beim Windows-Default.

### Was genau gesetzt wird

| Wert | Soll | Windows-Default | Wirkung |
| --- | --- | --- | --- |
| `AppsUseLightTheme` | `0` | `1` | dunkle Apps |
| `SystemUsesLightTheme` | `0` | `1` | dunkle Systemflächen |
| `EnableTransparency` | `1` | `1` | Transparenz/Blur |
| `TaskbarAl` | `1` | `1` | Taskleiste zentriert |
| `SearchboxTaskbarMode` | `0` | `2` | Suchfeld aus |
| `ShowTaskViewButton` | `0` | `1` | Task-View aus |
| `TaskbarDa` | `0` | `1` | Widgets aus – **OS-geschützt**, wird nicht geschrieben |
| `HideFileExt` | `0` | `1` | Dateiendungen sichtbar |

Die Defaults stehen in der Konfiguration, damit ein **fehlender** Registry-Wert
nicht fälschlich als Abweichung gilt.

## 3. Taskleiste aktualisieren

Meist genügt ein Moment. Wenn nicht: ab- und wieder anmelden. Kein Neustart
nötig, kein Explorer-Patch.

## 4. Akzentfarbe manuell setzen

**Einstellungen → Personalisierung → Farben**

1. Modus: **Dunkel**.
2. Akzentfarbe: **Benutzerdefinierte Farben** → `#007AFF` (Mac-Blau).
3. **Transparenzeffekte** einschalten.
4. „Akzentfarbe auf Start und Taskleiste anzeigen“ **aus** lassen. macOS färbt
   Titelleisten neutral; die Akzentfarbe soll nur Controls und Fokus markieren.

Das Skript schreibt `AccentColor` bewusst nicht: Windows baut die Akzentpalette
beim Setzen über die Einstellungen neu auf, ein einzelner Registry-Wert reicht
dafür nicht zuverlässig.

## 5. Wallpaper manuell setzen

**Einstellungen → Personalisierung → Hintergrund → Bild** und ein eigenes Bild
wählen. Aus Lizenzgründen werden **keine** macOS-Wallpaper mitgeliefert oder
empfohlen.

Optional, für eine prüfbare Referenz: SHA-256 des Bildes berechnen und in
`config/macified.psd1` unter `Look.Wallpaper.ExpectedSha256` eintragen. Danach
prüft der Verifier den tatsächlich gesetzten Pfad und Hash.

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath .\mein-wallpaper.jpg
```

## 6. LocalSend 1.18.2

Bereits installiert. Offen sind Firewall-Geltungsbereich und Netzwerkprofil:

1. Netzwerkprofil des Ethernet-Adapters auf **Privat** stellen
   (Einstellungen → Netzwerk & Internet → Ethernet → Netzwerkprofiltyp).
2. Firewall-Regeln für LocalSend auf **Privat** begrenzen, Public entfernen
   (Windows-Sicherheit → Firewall → App zulassen; Admin nötig).
3. LocalSend einmal starten und Gerätenamen prüfen.

Details, Test und Rücknahme: [`apps/localsend.md`](apps/localsend.md).

## 7. Deskreen CE 3.2.16 (DisplayShare, optional)

Nur manuell, nur von der offiziellen Release-Seite, Hash vor dem Start prüfen.
Für **erweiterten** Desktop ist zusätzlich ein virtueller Monitor nötig; ohne
ihn ist nur Spiegeln oder ein einzelnes Fenster möglich.

Details: [`apps/deskreen.md`](apps/deskreen.md). Kein Autostart, keine
dauerhafte Freigabe.

## 8. AirPods Pro 3

Die AirPods sind bereits gekoppelt und als Audioendpunkte sichtbar. Zu prüfen
sind nur noch Klang, Mikrofon und die tatsächliche Generation:

1. AirPods einsetzen, Windows-Ausgabe auf „Kopfhörer (AirPods Pro …)“ stellen.
2. Musik/Video in Stereo testen.
3. Für Teams/Zoom das Headset-Mikrofon wählen und die Umschaltung auf HFP
   bewusst akzeptieren (mono, Telefonqualität).
4. Batterieanzeige, Spatial Audio und Firmware-Update nicht unter Windows
   erwarten.

Details und Grenzen: [`apps/airpods-pro-3.md`](apps/airpods-pro-3.md).

## 9. Abschlussprüfung

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Test-MacifiedState.ps1
```

Erwartet nach Setup:

- `Look`: sieben Werte PASS, `TaskbarDa` WARN (OS-geschützt)
- `Look / Accent`: PASS bei `#007AFF`, sonst WARN
- `Look / Wallpaper`: WARN, solange kein Referenzhash gesetzt ist
- `Apps / LocalSend`: PASS (1.18.2)
- `Apps / Firewall` und `Apps / Netzwerkprofil`: PASS nur nach den manuellen Schritten
- `Apps / Deskreen` und `Virtual display`: WARN, solange nicht eingerichtet
- `Gate / AirPods`: PASS (bereit) bei verbundenen AirPods, sonst WARN („paired, not connected“); hörbarer Test bleibt manuell
- `Repo`: PASS

Danach die visuelle Abnahme aus [`verify.md`](verify.md) durchführen.
