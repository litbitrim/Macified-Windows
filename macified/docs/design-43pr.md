# Optionale Design-Inspiration: 43PR/dotfiles (MIT)

## Zweck und Grenzen

[43PR/dotfiles](https://github.com/43PR/dotfiles) ist ein Hyprland-/Quickshell-
Setup für Arch-basierte Distributionen (CachyOS, EndeavourOS, Manjaro). Es ist
**kein** macOS-Theme und läuft nicht unter Windows. Die Lizenz ist **MIT**
([LICENSE](https://github.com/43PR/dotfiles/blob/main/LICENSE)), daher sind
Ideen und Kennwerte mit Attribution nutzbar.

Übernommen werden **nur** Farbwerte, Abstände, Radien und Bewegungszeiten als
Inspiration. Es wird **keine** Datei kopiert: kein QML, kein Lua, kein Shell-
Skript, keine Paketliste, keine Keybinds. Die Zahlen wurden am 2026-10-21 aus
`default.toml`, `Theme.qml`, `Bar.qml` und `look.lua` gelesen.

## Palette (Default)

| Rolle | Wert |
| --- | --- |
| Hintergrund | `#000000` |
| Panel | `#050505` |
| Karte | `#0D0D0D` |
| Track | `#161616` |
| Rahmen | `#151515` |
| Rahmen akzentuiert | `#2A2A2A` |
| Text | `#FFFFFF` |
| Text weich | `#E6EAF2` |
| Text gedimmt | `#C2C2C2` |
| Text stumm | `#8B93A7` |
| Text schwach | `#4A4A4A` |
| Highlight | `#7AA2F7` |
| Gefahr | `#FF003C` |
| Warnung | `#F7768E` |
| Erfolg | `#00FF9C` |

Nord-Alternative: Hintergrund `#2E3440`, Panel `#292E39`, Karte `#3B4252`,
Text `#ECEFF4`, Akzent `#88C0D0`, Gefahr `#BF616A`, Erfolg `#A3BE8C`.

## Maße und Bewegung

| Token | Wert |
| --- | --- |
| Radius allgemein / Bar / Kalender / Fenster | 10 / 16 / 15 / 8 px |
| Bar-Höhe / Rand / Deckkraft | 20 px / 4 px / 0,5 |
| Modul-Padding / Workspace-Punkte / Lücke | 20 / 10 / 8 px |
| Typografie (Titel/Sektion/Gruppe/Body/Small) | 18 / 15 / 12 / 11 / 10 px |
| Bewegung schnell / mittel / langsam | 120 / 220 / 380 ms |
| Hover-Farbe / Tooltip-Verzögerung | 100 ms / 450 ms |

## Sieben portierbare Ideen

| # | Idee aus 43PR | Windows-Umsetzung | Grenze |
| --- | --- | --- | --- |
| 1 | **Eine** Akzentfarbe, alles andere neutral | Windows-Akzent `#007AFF`, Oberflächen dunkel/neutral | Systemflächen lassen sich ohne Patch nicht frei einfärben |
| 2 | Oberflächen-Leiter (Schwarz → Panel → Karte) statt Schatten | In eigenen WPF-/WinUI-Widgets drei Ebenen nutzen | Kein Eingriff in Explorer/Taskleiste |
| 3 | Dreizonige Leiste (Start / Mitte / Ende) | Taskleiste bleibt zentriert; eine spätere Dock-App könnte Zonen übernehmen | Taskleiste ist nicht frei umbaubar |
| 4 | Ruhige Radien 8–16 px | In eigenen Fenstern/Widgets konsistent runden | Windows-11-Ecken sind systemgesteuert, nicht patchen |
| 5 | Kurze Zustandswechsel (100–220 ms), lange nur für Layout (380 ms) | In eigenen Widgets; Systemanimationen unangetastet lassen | Keine globalen Animations-Hacks |
| 6 | Semantische Statusfarben (Erfolg/Warnung/Gefahr) | Idee für ein späteres Status-Panel: LocalSend-Transfer, AirPods-Akku, Deskreen-Sitzung | Erfordert eigene UI, hier nicht implementiert |
| 7 | Klare Typo-Hierarchie (18/15/12/11/10) | Größenraster für eigene Panels; Systemschrift statt mitgelieferter Fonts | JetBrains Mono wird nicht ausgeliefert |

## Was bewusst **nicht** übernommen wird

- Quickshell/QML-Laufzeit und `.qml`-Dateien
- Hyprland-Konfiguration in Lua, Fensterregeln, Workspaces
- Arch-Paketlisten, `systemd`-Units, Installer
- Keybinds und Compositor-Verhalten
- GTK-/Terminal-Themes und Schriftdateien
- die konkrete „schwarz-weiße Utility-Bar“ als Nachbau: Sie ist kein macOS-Look

## Verhältnis zur Baseline

Die Baseline in [`../config/macified.psd1`](../config/macified.psd1) nutzt nur
Windows-Bordmittel. 43PR liefert die **Gestaltungsdisziplin** für spätere eigene
Widgets, nicht den Look selbst. Wer heute ein Dock oder eine Menüleiste will,
muss ein separates, lizenzgeprüftes Programm wählen; dieses Paket liefert
bewusst keines.

## Attribution

Design-Inspiration: [43PR/dotfiles](https://github.com/43PR/dotfiles), MIT License.
Es wurde kein Code übernommen; die MIT-Lizenz des Originals bleibt unberührt.
