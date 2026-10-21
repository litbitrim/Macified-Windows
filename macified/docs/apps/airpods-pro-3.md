# AirPods Pro 3 unter Windows 11 26H2

## Kurzfassung

Die AirPods funktionieren als normale Bluetooth-Kopfhörer: Stereo-Wiedergabe
über A2DP, Mikrofon über HFP. Apple-Funktionen wie Spatial Audio, Head Tracking,
automatisches Umschalten und Firmware-Updates bleiben Apple-Geräten vorbehalten.
Die **Hardware ist erkannt**. Der Nutzer hat zwei kurze Windows-Testtöne in den AirPods klar gehört. Mikrofon und Modellgeneration sind noch offen.

## Gemessener Zustand (2026-10-21)

| Prüfung | Ergebnis |
| --- | --- |
| Bluetooth-Radio | `USB\VID_0A12&PID_0001`, Generic Bluetooth Radio, Status OK (CSR-Klasse) |
| Gekoppeltes Gerät | „AirPods Pro von Jamil“, `BTHENUM\DEV_747786838AC3` |
| A2DP/AVRCP | Transports `BTHENUM {110B}`, `{110C}`, `{110E}` vorhanden |
| Audioendpunkte | „Kopfhörer (AirPods Pro …)“ und „… Hands-Free“ vorhanden; bei Verbindung Status OK, im Case `Unknown` |
| `btaudio`-Dienst | nicht installiert – **kein** Blocker, HFP läuft über `BTHHFENUM` |
| Generation | aus Windows **nicht** bestimmbar; Name nennt nur „AirPods Pro“ |

Der frühere Eindruck „Bluetooth-Hardware nicht erkannt“ beruhte vermutlich auf
einer Momentaufnahme ohne gekoppeltes Gerät. Ein `Get-PnpDevice -PresentOnly`
lieferte zeitweise nur das Radio; die vollständige Enumeration zeigt die AirPods.

## Gate: READY vs. VERIFIED

| Stufe | Kriterium | Status |
| --- | --- | --- |
| **PAIRED** | Gerät ist gekoppelt | erreicht |
| **READY** (automatisch) | gekoppelt **und** aktiver Audioendpunkt (Status OK) | erreicht, solange die AirPods verbunden sind; im Case `WARN` |
| **STEREO VERIFIED** (manuell) | Windows-Testtöne hörbar | **erreicht**, vom Nutzer bestätigt |
| **FULL VERIFIED** (manuell) | Mikrofon im Call getestet, Generation bestätigt | **offen** |

Der Verifier prüft nur PAIRED/READY. Klang, Mikrofonqualität und die
tatsächliche Generation kann kein Skript beurteilen. `WARN` bedeutet „gekoppelt,
aber gerade nicht verbunden“, nicht „defekt“.

## Koppeln (falls neu)

1. AirPods in das Case, Deckel öffnen.
2. Vorderseite des Case doppelt antippen, bis die Statusleuchte **weiß** blinkt.
3. Windows: Einstellungen → Bluetooth & Geräte → Gerät hinzufügen →
   Bluetooth → „AirPods Pro“ auswählen.
4. Nach dem Koppeln erscheinen zwei Endpunkte: „Kopfhörer“ (A2DP, Stereo) und
   „Hands-Free“ (HFP, Mikrofon).

Quelle: Apple, „AirPods mit dem Mac und anderen Bluetooth-Geräten einrichten“
(https://support.apple.com/en-us/108786).

## Was unter Windows funktioniert

| Funktion | Verhalten |
| --- | --- |
| Musik/Video | Stereo über A2DP; Codec AAC oder SBC je nach Adapter/Treiber, nicht garantiert |
| ANC / Transparenz | über die Stielsteuerung der AirPods, unabhängig von Windows |
| Mikrofon in Teams/Zoom | ja, über HFP; Wiedergabe wird dabei mono und telefonartig |
| Lautstärke/Stummschaltung | über Windows und die AirPods |
| Akkuanzeige | nicht nativ zuverlässig; Windows zeigt nur, was das Gerät bereitstellt |
| Firmware-Update | **nur** über iPhone/iPad/Mac mit WLAN; sonst Apple Store/Service |
| Spatial Audio / Head Tracking | unter Windows nicht verfügbar |
| Adaptive Audio / Conversation Awareness | unter Windows nicht steuerbar |
| Automatisches Umschalten / Multipoint | nicht wie im Apple-Ökosystem; Umschalten manuell |

Quellen: Apple AirPods Pro 3 Technische Daten
(https://support.apple.com/en-us/125135), Apple Firmware-Updates
(https://support.apple.com/en-us/106340), Microsoft Bluetooth Classic Audio
(https://learn.microsoft.com/en-us/windows-hardware/drivers/bluetooth/bluetooth-classic-audio).

## Testprotokoll (V13/V14)

1. AirPods einsetzen (nehmen sie aus dem Case, verbinden sie sich), Ohreinsatz korrekt, Bluetooth an.
2. Ausgabe: „Kopfhörer (AirPods Pro …)“ wählen (nicht „Hands-Free“).
3. Stereo-Test: Titel mit klarer Links/Rechts-Trennung abspielen; beide Seiten
   müssen getrennt hörbar sein.
4. Mikrofon-Test: Teams-Testanruf oder Sprachaufnahme; Eingabe
   „… Hands-Free“ wählen. Erwartet: Sprache klar, Wiedergabe wechselt auf mono.
5. Danach Ausgabe zurück auf „Kopfhörer“, falls die Qualität im Call stört.
6. Generation prüfen: auf einem Apple-Gerät Einstellungen → Bluetooth → ⓘ neben
   den AirPods → Modellnummer; alternativ Aufdruck am Case.

## Bekannte Risiken

- **Generisches CSR-Radio**: Aussetzer, Reichweite und Codec-Aushandlung sind
  nicht garantiert. USB-3-Ports können stören; ein USB-2-Port oder ein kurzes
  Verlängerungskabel hilft häufig (Microsoft Bluetooth-Fehlerbehebung:
  https://support.microsoft.com/en-us/windows/hardware/bluetooth/fix-bluetooth-problems-in-windows).
- **Kein `btaudio`**: normal für moderne HFP-Geräte, kein Reparaturbedarf.
- **Firmware veraltet**: ohne Apple-Gerät nicht aktualisierbar.
- **Kein Multipoint**: gleichzeitige Nutzung von PC und iPhone ist nicht
  verlässlich; Gerätewechsel manuell.
- **Batterie**: nicht nativ; Drittanbieter-Apps wären eine separate
  Vertrauensentscheidung und sind hier bewusst nicht integriert.

## Rücknahme

Gerät entfernen: Einstellungen → Bluetooth & Geräte → AirPods → Gerät entfernen.
Damit verschwinden beide Audioendpunkte. Die AirPods selbst bleiben unverändert.
