//
//  BLEManager.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import CoreBluetooth
import Combine
import OSLog

// Manages Bluetooth connections
class BLEManager: NSObject, ObservableObject {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.g1teleprompter", category: "BLEManager")
    private var centralManager: CBCentralManager!
    
    // Devices
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedDevices: [BLEDeviceStatus] = []
    @Published var knownDevices: [KnownDevice] = []
    
    // Status
    @Published var isScanning: Bool = false
    @Published var centralState: CBManagerState = .unknown
    @Published var lastError: Error? = nil
    
    // Protocol profiles
    @Published var activeProfile: ProtocolProfile?
    @Published var availableProfiles: [ProtocolProfile] = []
    
    // Device sessions
    private var deviceSessions: [UUID: BLEDeviceSession] = [:]
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Init CoreBluetooth
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        
        // Dedicated queue for BLE operations
        let queue = DispatchQueue(label: "com.g1teleprompter.blequeue", qos: .userInitiated)
        centralManager = CBCentralManager(delegate: self, queue: queue, options: options)                                                                         
        
        // Load saved devices and profiles
        loadKnownDevices()
        loadProfiles()
    }
    
    // MARK: - Public Methods
    
    // Start scanning for BLE devices
    func startScan() {
        guard centralManager.state == .poweredOn else {
            logger.warning("Bluetooth not powered on")
            lastError = BLEError.bluetoothNotPoweredOn
            return
        }
        
        discoveredPeripherals.removeAll()
        isScanning = true
        
        // Scan for all devices
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        logger.info("BLE scan started")
    }
    
    // Stop scanning
    func stopScan() {
        centralManager.stopScan()
        isScanning = false
        logger.info("BLE scan stopped")
    }
    
    // Connect to device
    func connect(to peripheral: CBPeripheral, as role: DeviceRole = .unknown) {
        logger.info("Connecting to device: \(peripheral.name ?? "Unknown")")
        
        // Check if already connected
        if connectedDevices.contains(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            logger.info("Device already connected")
            return
        }
        
        // Create or update known device
        let knownDevice: KnownDevice
        if let existingDevice = knownDevices.first(where: { $0.identifier == peripheral.identifier.uuidString }) {
            knownDevice = existingDevice
        } else {
            knownDevice = KnownDevice(from: peripheral, role: role)
            knownDevices.append(knownDevice)
            saveKnownDevices()
        }
        
        // Create device status and add to list
        let deviceStatus = BLEDeviceStatus(knownDevice: knownDevice, peripheral: peripheral)
        deviceStatus.isConnecting = true
        connectedDevices.append(deviceStatus)
        
        // Connect to the device
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Disconnects from a device
    func disconnect(deviceId: UUID) {
        guard let deviceStatus = connectedDevices.first(where: { $0.id == deviceId }),
              let peripheral = deviceStatus.peripheral else {
            return
        }
        
        logger.info("Disconnecting from device: \(peripheral.name ?? "Unknown")")
        centralManager.cancelPeripheralConnection(peripheral)
        
        // Remove the session
        deviceSessions[deviceId] = nil
    }
    
    /// Sends text to a device
    func sendText(_ text: String, to deviceId: UUID) async -> Result<Void, Error> {
        guard let session = deviceSessions[deviceId],
              let activeProfile = activeProfile else {
            return .failure(BLEError.noActiveSession)
        }
        
        do {
            // Use the active profile to format the text
            if let sendCommand = activeProfile.commands["SEND_TEXT"] {
                let formattedText = sendCommand.format(with: ["text": text])
                try await session.writeData(formattedText, using: activeProfile)
                return .success(())
            } else {
                // Fallback: Send text directly
                try await session.writeData(text, using: activeProfile)
                return .success(())
            }
        } catch {
            logger.error("Error sending text: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    /// Sends text to all connected devices
    func broadcastText(_ text: String) async -> [UUID: Result<Void, Error>] {
        var results: [UUID: Result<Void, Error>] = [:]
        
        for device in connectedDevices where device.isConnected {
            results[device.id] = await sendText(text, to: device.id)
        }
        
        return results
    }
    
    /// Automatically connects to known devices
    func reconnectSavedDevices() async {
        logger.info("Attempting to connect to known devices")
        
        // Check on the main thread if Bluetooth is turned on
        guard await MainActor.run(body: { centralManager.state == .poweredOn }) else {
            logger.warning("Bluetooth is not turned on")
            return
        }
        
        // Look for devices that should be automatically connected
        let devicesToReconnect = knownDevices.filter { $0.autoReconnect }
        
        if devicesToReconnect.isEmpty {
            logger.info("No devices configured for automatic connection")
            return
        }
        
        // Start scanning for known devices
        isScanning = true
        
        // Use retrievePeripherals to find known devices
        let identifiers = devicesToReconnect.compactMap { UUID(uuidString: $0.identifier) }
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: identifiers)
        
        for peripheral in peripherals {
            if let knownDevice = knownDevices.first(where: { $0.identifier == peripheral.identifier.uuidString }) {
                connect(to: peripheral, as: knownDevice.role)
            }
        }
        
        // Stop scan after a reasonable time
        isScanning = false
    }
    
    /// Saves a new protocol profile
    func saveProfile(_ profile: ProtocolProfile) {
        if let index = availableProfiles.firstIndex(where: { $0.id == profile.id }) {
            availableProfiles[index] = profile
        } else {
            availableProfiles.append(profile)
        }
        
        saveProfiles()
    }
    
    /// Activates a protocol profile
    func activateProfile(_ profileId: UUID) {
        guard let profile = availableProfiles.first(where: { $0.id == profileId }) else {
            return
        }
        
        activeProfile = profile
        
        // Update sessions with the new profile
        for (deviceId, session) in deviceSessions {
            session.updateProfile(profile)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadKnownDevices() {
        if let data = UserDefaults.standard.data(forKey: "KnownDevices"),
           let devices = try? JSONDecoder().decode([KnownDevice].self, from: data) {
            knownDevices = devices
        } else {
            knownDevices = []
        }
    }
    
    private func saveKnownDevices() {
        if let data = try? JSONEncoder().encode(knownDevices) {
            UserDefaults.standard.set(data, forKey: "KnownDevices")
        }
    }
    
    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: "BLEProfiles"),
           let profiles = try? JSONDecoder().decode([ProtocolProfile].self, from: data) {
            availableProfiles = profiles
            
            // Set the active profile if available
            if let activeProfileId = UserDefaults.standard.string(forKey: "ActiveProfileId"),
               let id = UUID(uuidString: activeProfileId),
               let profile = profiles.first(where: { $0.id == id }) {
                activeProfile = profile
            } else if let firstProfile = profiles.first {
                activeProfile = firstProfile
            } else {
                // Create a default profile if none exists
                let defaultProfile = ProtocolProfile.defaultProfile
                availableProfiles.append(defaultProfile)
                activeProfile = defaultProfile
                saveProfiles()
            }
        } else {
            // Create a default profile
            let defaultProfile = ProtocolProfile.defaultProfile
            availableProfiles = [defaultProfile]
            activeProfile = defaultProfile
            saveProfiles()
        }
    }
    
    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(availableProfiles) {
            UserDefaults.standard.set(data, forKey: "BLEProfiles")
        }
        
        if let activeProfile = activeProfile {
            UserDefaults.standard.set(activeProfile.id.uuidString, forKey: "ActiveProfileId")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralState = central.state
        
        switch central.state {
        case .poweredOn:
            logger.info("Bluetooth is turned on")
            // Automatic reconnection when Bluetooth is turned on
            Task {
                await reconnectSavedDevices()
            }
            
        case .poweredOff:
            logger.warning("Bluetooth is turned off")
            isScanning = false
            lastError = BLEError.bluetoothPoweredOff
            
        case .unauthorized:
            logger.error("Bluetooth permission not granted")
            lastError = BLEError.bluetoothUnauthorized
            
        case .unsupported:
            logger.error("Bluetooth is not supported on this device")
            lastError = BLEError.bluetoothUnsupported
            
        case .resetting:
            logger.warning("Bluetooth connection is being reset")
            
        case .unknown:
            logger.warning("Bluetooth status unknown")
            
        @unknown default:
            logger.warning("Unknown Bluetooth status")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Ignore devices without names
        guard let name = peripheral.name, !name.isEmpty else {
            return
        }
        
        // Check if the device has already been discovered
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            logger.info("New device found: \(name), RSSI: \(RSSI.intValue) dBm")
            discoveredPeripherals.append(peripheral)
        }
        
        // Update RSSI for connected devices
        if let index = connectedDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            connectedDevices[index].rssi = RSSI.intValue
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to device: \(peripheral.name ?? "Unknown")")
        
        // Update the device status
        if let index = connectedDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            connectedDevices[index].isConnected = true
            connectedDevices[index].isConnecting = false
            
            // Aktualisiere das KnownDevice
            if let knownDeviceIndex = knownDevices.firstIndex(where: { $0.identifier == peripheral.identifier.uuidString }) {
                knownDevices[knownDeviceIndex].lastConnected = Date()
                saveKnownDevices()
            }
            
            // Create a session for the device
            let deviceId = connectedDevices[index].id
            let session = BLEDeviceSession(peripheral: peripheral, deviceId: deviceId)
            deviceSessions[deviceId] = session
            
            // Start the session
            session.start(with: activeProfile)
            
            // Stop scanning when we're connected
            if isScanning {
                stopScan()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Connection to device failed: \(peripheral.name ?? "Unknown"), Error: \(error?.localizedDescription ?? "Unknown")")
        
        // Update the device status
        if let index = connectedDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            connectedDevices[index].isConnected = false
            connectedDevices[index].isConnecting = false
            connectedDevices[index].lastError = error
            
            // Remove the device from the list
            connectedDevices.remove(at: index)
        }
        
        lastError = error ?? BLEError.connectionFailed
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected from device: \(peripheral.name ?? "Unknown")")
        
        // Update the device status
        if let index = connectedDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
            connectedDevices[index].isConnected = false
            connectedDevices[index].isConnecting = false
            
            // Remove the device from the list
            connectedDevices.remove(at: index)
            
            // Remove the session
            deviceSessions[connectedDevices[index].id] = nil
        }
        
        // Try to automatically reconnect if an error occurred
        if let error = error,
           let knownDevice = knownDevices.first(where: { $0.identifier == peripheral.identifier.uuidString }),
           knownDevice.autoReconnect {
            logger.info("Attempting to automatically reconnect: \(peripheral.name ?? "Unknown")")
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        logger.info("Restoring BLE state")
        
        // Restoration of peripherals
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                logger.info("Restoring device: \(peripheral.name ?? "Unknown")")
                
                // Check if the device is known
                if let knownDevice = knownDevices.first(where: { $0.identifier == peripheral.identifier.uuidString }) {
                    // Create DeviceStatus and add it to the list
                    let deviceStatus = BLEDeviceStatus(knownDevice: knownDevice, peripheral: peripheral)
                    deviceStatus.isConnecting = true
                    connectedDevices.append(deviceStatus)
                    
                    // Reconnect to the device
                    centralManager.connect(peripheral, options: nil)
                }
            }
        }
    }
}

// MARK: - BLE Errors

enum BLEError: Error, LocalizedError {
    case bluetoothNotPoweredOn
    case bluetoothPoweredOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case connectionFailed
    case serviceNotFound
    case characteristicNotFound
    case writeError
    case readError
    case notifyError
    case noActiveSession
    case encodingError
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .bluetoothNotPoweredOn:
            return "Bluetooth is not turned on"
        case .bluetoothPoweredOff:
            return "Bluetooth is turned off"
        case .bluetoothUnauthorized:
            return "Bluetooth permission not granted"
        case .bluetoothUnsupported:
            return "Bluetooth is not supported on this device"
        case .connectionFailed:
            return "Connection to device failed"
        case .serviceNotFound:
            return "BLE service not found"
        case .characteristicNotFound:
            return "BLE characteristic not found"
        case .writeError:
            return "Error writing data"
        case .readError:
            return "Error reading data"
        case .notifyError:
            return "Error with notifications"
        case .noActiveSession:
            return "No active BLE session"
        case .encodingError:
            return "Error in data encoding"
        case .timeout:
            return "Timeout during BLE operation"
        }
    }
}
