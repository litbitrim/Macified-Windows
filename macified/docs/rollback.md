# Rollback

Grundsatz: Jede Änderung ist umkehrbar. Die Look-Baseline hinterlässt ein
Backup, alle manuellen Schritte haben einen dokumentierten Rückweg.

## 1. Look-Werte automatisch zurücknehmen

```powershell
# zuerst nur anzeigen
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Undo-MacifiedLook.ps1

# dann anwenden
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Undo-MacifiedLook.ps1 -Apply
```

Das Skript liest standardmäßig `%LOCALAPPDATA%\MacifiedWindows\last-apply.json`
und stellt den dort genannten Stand wieder her. Vor dem Wiederherstellen prüft
es den SHA-256 des letzten Backups und der zugehörigen Konfiguration; bei einer
Abweichung bricht es ab. Es akzeptiert nur Werte, die in der Konfiguration
aufgeführt sind, und prüft Pfad sowie Datentyp.

Wurde die letzte Konfigurationsdatei verschoben, kann `-ConfigPath` auf eine
inhaltlich identische Kopie zeigen. Eine geänderte Datei wird auch bei explizitem
`-ConfigPath` abgelehnt.

Ein älteres oder manuell ausgewähltes Backup wird gegen die Standardkonfiguration
geprüft. Wurde es mit einer eigenen Konfiguration erstellt, diese explizit
angeben:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Undo-MacifiedLook.ps1 `
  -BackupPath "$env:LOCALAPPDATA\MacifiedWindows\backups\look-20261021-143000.json" `
  -ConfigPath .\my-macified.psd1 -Apply
```

Für ältere/manuelle Backups ist kein ursprünglicher SHA-256-Wert gespeichert;
das Skript warnt davor und begrenzt die Wiederherstellung weiterhin auf die
konfigurierten Pfade und Datentypen. Nur das letzte Apply wird gegen die
gespeicherten Backup- und Config-Hashes geprüft.

Werte, die vorher **nicht existierten**, werden entfernt, nicht auf `0` gesetzt.
Damit gilt wieder der Windows-Default. `TaskbarDa` wurde nie geschrieben; ein
etwaiger Fehler beim Wiederherstellen wird gemeldet und mit Exit 2 quittiert.

## 2. Look manuell zurückstellen

Falls kein Backup mehr vorhanden ist, in den Einstellungen:

| Einstellung | Zurück auf |
| --- | --- |
| Apps/Windows-Modus | Hell (oder vorherigen Modus) |
| Transparenz | aus |
| Taskleiste | linksbündig (Einstellungen → Personalisierung → Taskleiste → Verhalten) |
| Suche in Taskleiste | Suchfeld anzeigen |
| Task-View-Schaltfläche | einblenden |
| Widgets | OS-geschützt; bleibt beim Default, kein Registry-Rollback möglich |
| Dateiendungen | ausblenden (Explorer → Ansicht → Dateiendungen) |
| Akzentfarbe | Windows-Blau `#0078D4` |
| Hintergrund | vorheriges Bild / Windows-Standard |

Registry-Referenz (nur zur Kontrolle, keine Empfehlung zum direkten Editieren):

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize
    AppsUseLightTheme   = 1
    SystemUsesLightTheme = 1
    EnableTransparency  = 1
HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced
    TaskbarAl           = 1   (Windows-11-Default: zentriert)
    SearchboxTaskbarMode = 2
    ShowTaskViewButton  = 1
    TaskbarDa           = 1
    HideFileExt         = 1
HKCU\Software\Microsoft\Windows\DWM
    AccentColor         = 0xFFD47800  (#0078D4)
```

## 3. LocalSend zurücknehmen

LocalSend war bereits vor dieser Arbeit installiert. Ein Rollback betrifft nur
die hier dokumentierten Netzwerk-/Firewall-Empfehlungen:

1. Firewall-Regeln für LocalSend wieder auf den vorherigen Geltungsbereich
   setzen oder entfernen (Windows-Sicherheit → Firewall → App zulassen, Admin).
2. Netzwerkprofil des Ethernet-Adapters wieder auf **Öffentlich** stellen,
   falls es vorher so war (war am 2026-10-21 `Public`).
3. Autostart: LocalSend ist derzeit **nicht** im `Run`-Key und **nicht** im
   Startup-Ordner eingetragen; es muss also nichts entfernt werden.
4. Deinstallation nur, falls gewünscht:
   `winget uninstall --id LocalSend.LocalSend --exact` oder
   Einstellungen → Apps → LocalSend → Deinstallieren.

## 4. Deskreen zurücknehmen

- Portable Variante: Prozess beenden, Datei löschen, fertig. Keine Registry-Reste.
- MSI: Einstellungen → Apps → Deskreen CE → Deinstallieren.
- Virtueller Monitor: im Geräte-Manager deinstallieren und die zugehörige
  Software entfernen. Ohne diesen Schritt bleibt ein zusätzlicher Monitor
  sichtbar. Die Deinstallation eines Display-Treibers kann einen Neustart
  erfordern.
- Firewall-Freigaben für Deskreen entfernen.

## 5. AirPods zurücknehmen

Einstellungen → Bluetooth & Geräte → „AirPods Pro …“ → Gerät entfernen.
Danach sind die Audioendpunkte sofort weg. Ein Firmware- oder Kopplungszustand
in den AirPods selbst wird dadurch nicht verändert.

## 6. Was **nicht** verändert wurde

- keine Systemdateien, kein `uxinit`/`Themeui`-Patch
- keine `HKLM`-Werte, keine Dienste, keine Gruppenrichtlinien
- kein Deinstallieren oder Installieren von Apps
- keine Wiederherstellungspunkte (bewusst dem Nutzer überlassen)

Falls Windows nach dem Undo die Taskleiste nicht sofort neu zeichnet: ab- und
wieder anmelden. Kein Explorer-Patch, kein Neustart nötig.
