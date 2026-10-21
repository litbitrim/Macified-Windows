# DisplayShare mit Deskreen CE 3.2.16

## Status

| Merkmal | Wert |
| --- | --- |
| Windows-App | **aktuell gestoppt**; kein Listener auf TCP 3131, lokaler Viewer antwortet nicht |
| Firewall | Allow-Regeln zeigen auf einen veralteten Temp-Pfad; aktives Netzwerkprofil `Public` |
| Virtueller Monitor | **nein**; kein Virtual Display Adapter vorhanden |
| Mac-Viewer | nicht getestet; keine Hostfreigabe bestätigt |
| Lizenz | **AGPL-3.0** |
| Upstream | [pavlobu/deskreen](https://github.com/pavlobu/deskreen), Tag [v3.2.16](https://github.com/pavlobu/deskreen/releases/tag/v3.2.16) |
| Release-Datum | 2026-07-08 |
| Windows-Artefakte | `deskreen-ce-3.2.16-x64.exe` (portable), `deskreen-ce-3.2.16-x64.msi` |
| Electron | Manifest `^37.9.0`; 37.x ist seit 2026-01-13 End-of-Support |

Deskreen CE ist die offizielle Community Edition aus dem Upstream-Repository,
kein separater Fork. Es zeigt einen Windows-Bildschirm in einem Browser auf
einem anderen Gerät im selben Netz.

Der native Windows-Projektionspfad ist auf diesem Host nicht verfügbar: der
Read-only-Check fand keinen Wi-Fi-Direct-Adapter, keinen Wireless-Display-Dienst
und keine Connect-/Projection-Empfänger-App. Deskreen kann Bildschirmspiegelung
im Browser bereitstellen, ersetzt aber keinen virtuellen Monitor für einen
erweiterten Desktop. Die gewünschte DisplayShare-Funktion mit
Rea/Morulot-Parität ist damit nicht nachgewiesen.

## Wichtig: Spiegeln vs. erweitern

- **Spiegeln** oder ein einzelnes Fenster teilen funktioniert ohne Zusatz.
- **Erweiterter Desktop** braucht einen **virtuellen Monitor**. Ohne ihn hat
  Windows keine zweite Anzeigefläche, auf die Deskreen ausdehnen könnte.

Ein virtueller Display-Treiber ist ein Systemtreiber mit eigener Lizenz und
eigenem Risiko. Er wird hier **nicht** mitgeliefert, nicht empfohlen und nicht
automatisch installiert. Wer ihn nutzt, prüft Herkunft, Signatur und Lizenz
selbst und deinstalliert ihn beim Rückbau.

## Bezug und Integrität

Nur von der offiziellen Release-Seite laden, niemals aus dem archivierten
Macified-Upstream. Prüfsummen aus den Release-Metadaten vom 2026-10-21:

| Datei | SHA-256 |
| --- | --- |
| `deskreen-ce-3.2.16-x64.exe` | `de6052a0d5dc893e0d16da6a8da82aacae5803602a3efdde50037b536e3213f8` |
| `deskreen-ce-3.2.16-x64.msi` | `9c890626f9a7db5590b9885f862f83f6a8c1526d97ad860e146e8cf7b52ddea6` |

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Test-DownloadIntegrity.ps1 `
  -Path .\deskreen-ce-3.2.16-x64.exe `
  -Sha256 de6052a0d5dc893e0d16da6a8da82aacae5803602a3efdde50037b536e3213f8
```

Das Skript startet nichts. Ohne `-ExpectedPublisher` meldet es **WARN** und
Exit-Code 2: Hash, Authenticode-Status, Publisher und Dateiversion werden
angezeigt, der Herausgeber wird aber nicht geprüft. Bei gesetztem Herausgeber
muss die Signatur gültig sein und der erwartete Name exakt dem einfachen
Zertifikatsnamen entsprechen. Die Signaturlage
der 3.2.16-Builds ist nicht dokumentiert. **Nicht** die Schutzsoftware
abschalten, nur weil ein Installer unsigniert ist.

## Einrichtung (manuell)

1. Datei laden, Hash prüfen (siehe oben).
2. Portable Variante bevorzugen: keine Installation, kein Dienst, kein
   Autostart. MSI nur, wenn eine Deinstallation über „Apps“ gewünscht ist.
3. Start **ohne** Administratorrechte.
4. Beim ersten Start die Windows-Firewall-Abfrage nur für **Private** erlauben.
5. „Share screen“ wählen, den gewünschten Monitor (oder das Fenster) auswählen.
6. Auf dem Zielgerät die angezeigte URL bzw. den QR-Code im Browser öffnen.
7. Verbindung am Host bestätigen; nur bekannte Geräte zulassen.
8. Nach der Nutzung **„Stop sharing“** und Deskreen beenden. Kein Dauerbetrieb.

## Test (V15/V16)

| Prüfung | Erwartung |
| --- | --- |
| Viewer lädt | Browser zeigt den PC-Bildschirm ohne schwarze Fläche |
| Bildrate/Bedienung | Mausbewegung und Fensterwechsel kommen sichtbar an |
| Stop sharing | Viewer verliert sofort das Bild, Prozess endet |
| Erweitern | nur mit virtuellem Monitor: zweiter Bildschirm in den Anzeigeeinstellungen sichtbar |
| Netz | Zielgerät im selben privaten LAN, keine Portweiterleitung im Router |

## Sicherheit und Risiken

- **Bildschirminhalt = Daten**: Nur in vertrauenswürdigem Netz teilen, keine
  Passwortmanager, Chats oder Banking-Fenster während der Freigabe offen lassen.
- **Kein Internet-Expose**: keine Portfreigabe, kein Tunnel, kein öffentliches WLAN.
- **Electron 37 ist EOL**: keine Sicherheitsupdates für die Laufzeit mehr. Das ist
  ein Projektrisiko, kein nachgewiesener Exploit. Wer das nicht akzeptiert, muss
  auf eine gepflegte Alternative warten.
- **AGPL-3.0**: Binary nicht weitergeben, keine abgewandelte Fassung hosten, ohne
  den Quelltext anzubieten. Hier wird nur dokumentiert und geprüft, nichts
  weiterverbreitet.
- **Keine Autostart-/Dienst-Integration**: bewusst, um unbeabsichtigte Freigaben
  zu vermeiden.

## Rücknahme

- Portable: Prozess beenden, Datei löschen.
- MSI: Einstellungen → Apps → Deskreen CE → Deinstallieren.
- Virtueller Monitor: Geräte-Manager → Display-Adapter → deinstallieren, danach
  neu starten; Firewall-Freigaben entfernen.
- Keine Registry-Änderungen durch dieses Paket.
