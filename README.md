# G1 OpenTeleprompter iOS

An open-source companion app for Even Reality G1 Smart Glasses. This app lets you send text messages to G1 glasses via Bluetooth LE, with support for teleprompter functions, templates, and more.

## Features

### Bluetooth LE Communication
- Scan, connect, and manage G1 glasses
- Simultaneous connection to left and right glasses
- Auto-reconnect to known devices
- Configurable BLE profiles for different protocols

### Teleprompter
- Text scrolling with adjustable speed
- Pause markers (///)
- Mirroring and inversion
- Countdown timer before start

### Templates
- Save and manage text templates
- Tagging and favorites
- CloudKit synchronization
- Placeholders for dynamic content

### Additional Features
- Diagnostic tools for BLE connections
- Siri Shortcuts and App Intents
- Widgets for quick access
- Live Activities for teleprompter control
- Voice input for text

## Setup

### Requirements
- iOS 17.0 or higher
- Xcode 15.0 or higher
- Even Reality G1 Smart Glasses (already paired with the official Even app)

### Installation
1. Clone the repository
2. Open `even-g1-app.xcodeproj` in Xcode
3. Select your developer certificate
4. Build and run the app on your device

## BLE Protocol

The app uses a configurable BLE protocol to communicate with G1 glasses. The default profile is pre-configured for G1 but can be customized if needed.

### Example Protocol Profile

```json
{
  "name": "Standard G1 Profile",
  "serviceUUID": "6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
  "txCharacteristic": "6E400002-B5A3-F393-E0A9-E50E24DCCA9E",
  "rxCharacteristic": "6E400003-B5A3-F393-E0A9-E50E24DCCA9E",
  "writeType": "withoutResponse",
  "encoding": "utf8",
  "commands": {
    "SEND_TEXT": {
      "template": "{text}",
      "description": "Send text to glasses"
    },
    "CLEAR": {
      "template": "CLEAR",
      "description": "Clear display"
    }
  }
}
```

## Troubleshooting

### Bluetooth Connection Issues
- Make sure G1 glasses are powered on and in connection mode
- Verify that glasses have been paired with the official Even app
- Check if Bluetooth is enabled on your iOS device
- Try restarting the glasses

### Background Mode
- Enable "Background Mode" in settings
- Ensure the app has Bluetooth permissions
- Disable power-saving features for the app in iOS settings

### State Restoration
- If auto-reconnection isn't working, try restarting the app
- Delete known devices and reconnect them

## Contributing

Contributions to the project are welcome! Please create a pull request or issue on GitHub.

## License

This project is released under the MIT License. See LICENSE file for details.

## Contact

For questions or feedback: [feedback@even-reality.com](mailto:feedback@even-reality.com)