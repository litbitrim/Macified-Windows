# Status-Dashboard (read-only)

Kleine lokale Oberfläche für den aktuellen Zustand von LocalSend, AirPods,
Deskreen und der Look-Baseline. Sie ersetzt weder den Verifier noch die
visuelle Abnahme: Sie zeigt einen Snapshot, keine Messhistorie.

## Start

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Start-MacifiedDashboard.ps1
```

Danach `http://127.0.0.1:5555/` öffnen. Ein anderer Port:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\scripts\Start-MacifiedDashboard.ps1 -Port 5556
```

Beenden mit `Ctrl+C`. Der Server bindet ausschließlich an `127.0.0.1`; er ist
im LAN nicht erreichbar und öffnet keinen Browser.

## Was angezeigt wird

| Karte | Quellen | Bedeutung |
| --- | --- | --- |
| **Host** | Computername, `HKLM\...\CurrentVersion` | Header zeigt Name und Build; der JSON-Snapshot enthält zusätzlich OS und DisplayVersion. Windows 11 wird ab Build 22000 anhand der Buildnummer bezeichnet, da ProductName noch „Windows 10“ liefern kann. |
| **LocalSend** | Uninstall-Eintrag, Prozess, TCP-Tabelle, Firewall-Regeln, Netzwerkprofile | `Bereit` heißt: Listener auf 53317. Peers erscheinen nur bei bestehenden TCP-Verbindungen, nicht bei reiner Geräteerkennung. |
| **AirPods** | Bluetooth-PnP-Geräte, Audioendpunkte | A2DP/HFP werden getrennt gezählt. `Im Case` markiert vorhandene, aber inaktive Endpunkte. Batteriestand liefert Windows nicht. |
| **Deskreen** | Uninstall-Eintrag, Prozess, Display-PnP, TCP-Tabelle | Zeigt Installation, virtuellen Monitor und Anzahl bestehender Viewer-Verbindungen. Ohne virtuellen Monitor ist nur Spiegeln möglich. |
| **Baseline** | `config/macified.psd1`, `HKCU` | 8 Segmente für die Look-Werte, plus Taskleisten-Modus und der OS-geschützte `TaskbarDa`-Wert. |

Die Oberfläche fragt alle 5 Sekunden `/api/status` ab. Der Server hält einen
Snapshot ebenfalls 5 Sekunden lang, damit wiederholte Aufrufe nicht jedes Mal
alle Geräte abfragen. Einzelne Quellen sind länger gecacht: Firewall 30 s,
Netzwerk und Display 10 s, Bluetooth/PnP 5 s. Eine Karte kann deshalb kurz
hinterherhinken; ein Neustart des Servers erzwingt eine neue Abfrage.

## Read-only-Grenzen

- Collector und Server enthalten keine Schreib-, Installations- oder
  Startbefehle für Anwendungen.
- Der HTTP-Server beantwortet nur `GET`; andere Methoden erhalten `405`.
- Es gibt genau drei statische Dateien und einen JSON-Endpunkt. Pfade außerhalb
  dieser Liste liefern `404`.
- Keine externen Schriften, CDNs, Bilder oder Telemetrie. Die
  Content-Security-Policy erlaubt nur `'self'`.
- Keine Registrierung von Diensten, keine Autostart-Verknüpfung, keine
  Änderung an Firewall oder Netzwerkprofil.

Der Snapshot enthält Gerätenamen, Netzwerknamen und lokale Adressen. Deshalb
bleibt der Server auf Loopback beschränkt und sollte nicht über einen
Reverse-Proxy veröffentlicht werden.

## Grenzen der Aussage

- Der Collector läuft single-threaded; während einer Abfrage wartet der nächste
  Request. Die erste Abfrage kann ein bis drei Sekunden dauern.
- LocalSend-Peers sind nur etablierte TCP-Verbindungen. UDP-Discovery und
  Geräte, die gerade nichts senden, erscheinen nicht.
- Deskreen liefert nur die Anzahl der Verbindungen, keine Client-IPs oder
  Sitzungsdauer.
- AirPods: Windows zeigt keinen Batteriestand; die Generation Pro 3 lässt sich
  daraus nicht ableiten.
- Die Baseline-Segmente sind ein Snapshot des Verifiers. Ein grünes Segment
  bedeutet „Wert entspricht dem Soll“, nicht „visuell abgenommen“.

## Prüfen

```powershell
# Oberfläche und Header
$r = Invoke-WebRequest -Uri http://127.0.0.1:5555/ -UseBasicParsing
$r.StatusCode
$r.Headers['Content-Security-Policy']

# Snapshot
Invoke-RestMethod -Uri http://127.0.0.1:5555/api/status |
  Select-Object generatedAt, @{n='LocalSend';e={$_.localsend.status}}, @{n='AirPods';e={$_.airpods.status}}

# Tests inklusive Dashboard-Guardrails
powershell -NoProfile -ExecutionPolicy Bypass -File .\macified\tests\run-tests.ps1
```

Typische Fehlerbilder:

| Symptom | Ursache / Abhilfe |
| --- | --- |
| `Port 5555 ist belegt` | Anderen Port mit `-Port` wählen. |
| Banner „Collector offline“ | Server läuft nicht mehr oder wurde durch ein Timeout beendet; Konsole prüfen und neu starten. |
| Alle Karten `—` | Abfrage läuft noch oder die jeweilige App ist nicht installiert/gestartet. |
| LocalSend `Bereit`, aber keine Peers | Normal ohne aktive Übertragung; die App lauscht nur. |
| AirPods `Gekoppelt`, aber 0 aktiv | AirPods sind im Case oder getrennt; einsetzen und Karte aktualisieren lassen. |
