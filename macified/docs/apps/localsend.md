# LocalSend 1.18.2 – AirDrop-Ersatz im LAN

## Status

| Merkmal | Wert |
| --- | --- |
| Installiert | **ja**, 1.18.2, `C:\Program Files\LocalSend\localsend_app.exe` |
| Bezugsweg | WinGet `LocalSend.LocalSend` (bereits vorhanden) |
| Lizenz | Apache-2.0 |
| Quelle | [github.com/localsend/localsend](https://github.com/localsend/localsend), [Release v1.18.2](https://github.com/localsend/localsend/releases/tag/v1.18.2) |
| Firewall | 2 eingehende Allow-Regeln, Profil `Private, Public`, aktiv |
| Netzwerkprofil | Ethernet `Netzwerk` = `Public` |
| App-Settings | unter `%APPDATA%\LocalSend` **nicht vorhanden** → noch nicht eingerichtet/gestartet |
| Autostart | nicht eingetragen (weder `Run`-Key noch Startup-Ordner) |

## Wofür

Lokaler Datei- und Texttransfer zwischen Windows, Android, iOS, macOS und Linux
ohne Cloud-Konto. Geräte finden sich per Multicast im selben Netz, die Übertragung
läuft direkt von Gerät zu Gerät.

## Netzwerk und Sicherheit

- Discovery: UDP-Multicast an `224.0.0.167`, Port **53317**
- Übertragung: TCP, ebenfalls Port **53317**
- Windows-Empfehlung des Projekts: eingehend TCP/UDP 53317 erlauben, ausgehend
  TCP/UDP beliebig; Netzwerkprofil **Privat**
- AP-Isolation im Router verhindert die Gerätefindung
- Die aktuellen Regeln erlauben auch das Profil **Public**. Das ist breiter als
  nötig; auf fremden Netzen (Café, Hotel) sollte LocalSend nicht erreichbar sein.

## Einrichtung (manuell, Admin für Firewall/Netzwerkprofil)

1. **Netzwerkprofil auf Privat stellen**
   Einstellungen → Netzwerk & Internet → Ethernet → Netzwerkprofiltyp → „Privat“.
   Das ist eine Systemsichtbarkeit, keine LocalSend-Einstellung. Rückweg steht in
   [`../rollback.md`](../rollback.md).

2. **Firewall auf Privat begrenzen**
   Windows-Sicherheit → Firewall & Netzwerkschutz → App durch die Firewall
   zulassen → LocalSend: nur „Privat“ ankreuzen. Alternativ in einer
   **Admin-PowerShell**:

   ```powershell
   Get-NetFirewallRule -DisplayName 'LocalSend' | Set-NetFirewallRule -Profile Private
   ```

   Rückweg: `-Profile Private,Public` (nur wenn du das bewusst willst).

3. **LocalSend starten** und einmal einrichten:
   - Gerätename: z. B. `Jamil-PC` (erkennbar, ohne Klarnamen-Pflicht)
   - Sichtbarkeit: „Für alle im Netzwerk sichtbar“ nur im vertrauenswürdigen LAN
   - Speicherort für Empfang: eigener Ordner, nicht `C:\Windows` o. Ä.

4. **Autostart nur bewusst** (optional): Verknüpfung im Startup-Ordner mit
   `--hidden` startet LocalSend im Tray, nicht als Fenster. Ohne Autostart ist
   die App nur bei Bedarf aktiv – das ist die sicherere Voreinstellung.

5. **Test**
   - Zweites Gerät im selben WLAN, LocalSend installiert
   - PC → Gerät: kleine Datei senden, Größe/Hash vergleichen
   - Gerät → PC: Datei senden, Zielordner prüfen
   - Textnachricht senden (falls angeboten), um die Sitzung zu prüfen
   - Nach dem Test: Sichtbarkeit aus oder App schließen

## Prüfsummen (nur falls neu geladen wird)

Aus den offiziellen Release-Metadaten vom 2026-10-21:

| Datei | SHA-256 |
| --- | --- |
| `LocalSend-1.18.2-windows-x86-64.exe` | `122783e6abb4b0a1f1603d896f46a03aeda3004479ebd3175cab4ddac6b60919` |
| `LocalSend-1.18.2-windows-x86-64.zip` | `737aab1829d901e1d798cddd1e5fdc06ba9dfcc9ea50cfe3805e047005d5e71a` |
| `LocalSend-CLI-1.18.2-windows-x86-64.exe` | `ca0b267e7457324b3664a935de4e4956da701a7fa1045f6f99c72602f7f8dc38` |

Prüfen, ohne etwas zu starten:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Test-DownloadIntegrity.ps1 `
  -Path .\LocalSend-1.18.2-windows-x86-64.exe `
  -Sha256 122783e6abb4b0a1f1603d896f46a03aeda3004479ebd3175cab4ddac6b60919
```

Die Release-Assets wurden nach Veröffentlichung ergänzt (signierte EXE, ZIPs,
CLI). Prüfsummen daher immer gegen die aktuelle Release-Seite abgleichen.

## Ist-Stand prüfen

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Test-MacifiedState.ps1
```

Erwartete Zeilen nach der Einrichtung: `LocalSend installed version` PASS,
`LocalSend firewall scope` PASS (nur Private), `Active network profile for
discovery` PASS (Privat).

## Rücknahme

Siehe [`../rollback.md`](../rollback.md), Abschnitt 3. LocalSend war vor dieser
Arbeit installiert; ein Rollback entfernt nur die Firewall-/Netzwerkänderungen.

## Risiken

- Jedes Gerät im selben LAN kann bei sichtbarer App Dateien anbieten; nur in
  vertrauenswürdigen Netzen aktiv lassen.
- Öffentliches Netzwerkprofil plus Allow-Regel ist die größte aktuelle Abweichung.
- Tailscale ist als privates Netz vorhanden; LocalSend kann auf mehreren
  Schnittstellen announcen. Bei Problemen die gewünschte Schnittstelle prüfen.
- Port 53317 kann mit anderen Diensten kollidieren; dann in LocalSend ändern und
  die Firewall-Regel anpassen.
