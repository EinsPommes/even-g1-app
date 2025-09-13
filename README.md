# G1 OpenTeleprompter iOS

Eine Open-Source-Companion-App für Even Reality G1 Smart-Glasses. Diese App ermöglicht das Senden von Textbotschaften an die G1-Brille über Bluetooth LE, mit Unterstützung für Teleprompter-Funktionen, Vorlagen und mehr.

## Features

### Bluetooth LE Kommunikation
- Scannen, Verbinden und Verwalten von G1-Brillen
- Gleichzeitige Verbindung zu linker und rechter Brille
- Automatische Wiederverbindung mit bekannten Geräten
- Konfigurierbare BLE-Profile für verschiedene Protokolle

### Teleprompter
- Textscrolling mit einstellbarer Geschwindigkeit
- Pausenmarker (///)
- Spiegelung und Invertierung
- Countdown-Timer vor Start

### Vorlagen
- Speichern und Verwalten von Textvorlagen
- Tagging und Favoriten
- CloudKit-Synchronisierung
- Platzhalter für dynamische Inhalte

### Weitere Features
- Diagnose-Tools für BLE-Verbindungen
- Siri-Shortcuts und App-Intents
- Widgets für schnellen Zugriff
- Live-Activities für Teleprompter-Steuerung
- Spracheingabe für Text

## Einrichtung

### Voraussetzungen
- iOS 17.0 oder höher
- Xcode 15.0 oder höher
- Even Reality G1 Smart-Glasses (bereits mit der offiziellen Even-App gekoppelt)

### Installation
1. Klone das Repository
2. Öffne `even-g1-app.xcodeproj` in Xcode
3. Wähle dein Entwicklerzertifikat
4. Baue und starte die App auf deinem Gerät

## BLE-Protokoll

Die App verwendet ein konfigurierbares BLE-Protokoll, um mit den G1-Brillen zu kommunizieren. Das Standardprofil ist für die G1 vorkonfiguriert, kann aber bei Bedarf angepasst werden.

### Beispiel-Protokollprofil

```json
{
  "name": "Standard G1 Profil",
  "serviceUUID": "6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
  "txCharacteristic": "6E400002-B5A3-F393-E0A9-E50E24DCCA9E",
  "rxCharacteristic": "6E400003-B5A3-F393-E0A9-E50E24DCCA9E",
  "writeType": "withoutResponse",
  "encoding": "utf8",
  "commands": {
    "SEND_TEXT": {
      "template": "{text}",
      "description": "Text an Brille senden"
    },
    "CLEAR": {
      "template": "CLEAR",
      "description": "Display löschen"
    }
  }
}
```

## Fehlerbehebung

### Bluetooth-Verbindungsprobleme
- Stelle sicher, dass die G1-Brille eingeschaltet und im Verbindungsmodus ist
- Vergewissere dich, dass die Brille bereits mit der offiziellen Even-App gekoppelt wurde
- Überprüfe, ob Bluetooth auf deinem iOS-Gerät aktiviert ist
- Versuche, die Brille neu zu starten

### Hintergrundmodus
- Aktiviere "Hintergrundmodus" in den Einstellungen
- Stelle sicher, dass die App Bluetooth-Berechtigungen hat
- Deaktiviere Energiesparfunktionen für die App in den iOS-Einstellungen

### State Restoration
- Bei Problemen mit der automatischen Wiederverbindung, versuche die App neu zu starten
- Lösche bekannte Geräte und verbinde sie erneut

## Mitwirken

Beiträge zum Projekt sind willkommen! Bitte erstelle einen Pull Request oder ein Issue auf GitHub.

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz veröffentlicht. Siehe LICENSE-Datei für Details.

## Kontakt

Bei Fragen oder Feedback: [feedback@even-reality.com](mailto:feedback@even-reality.com)
