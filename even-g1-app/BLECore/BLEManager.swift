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

// Only accept BLE devices that are recognized as even g1 glasses
private let EVEN_G1_SERVICE_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")

private func isEvenG1Device(peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
    // Check device name
    if let name = peripheral.name?.lowercased(), name.contains("even g1") {
        return true
    }
    // Check for advertised service UUID
    if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
        return serviceUUIDs.contains(EVEN_G1_SERVICE_UUID)
    }
    return false
}

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
    internal var deviceSessions: [UUID: BLEDeviceSession] = [:]
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Init CoreBluetooth
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true,
            CBCentralManagerOptionRestoreIdentifierKey: "com.g1teleprompter.blemanager"
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
        await MainActor.run {
            isScanning = true
        }
        
        // Use retrievePeripherals to find known devices
        let identifiers = devicesToReconnect.compactMap { UUID(uuidString: $0.identifier) }
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: identifiers)
        
        for peripheral in peripherals {
            if let knownDevice = knownDevices.first(where: { $0.identifier == peripheral.identifier.uuidString }) {
                await MainActor.run {
                    connect(to: peripheral, as: knownDevice.role)
                }
            }
        }
        
        // Stop scan after a reasonable time
        await MainActor.run {
            isScanning = false
        }
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

    /// Deletes a known device by its identifier, disconnects it if connected, and removes it from auto-reconnect
    func deleteKnownDevice(withId id: String) {
        // Disconnect if connected
        if let uuid = UUID(uuidString: id), let connected = connectedDevices.first(where: { $0.id == uuid }), let peripheral = connected.peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            deviceSessions[uuid] = nil
            connectedDevices.removeAll { $0.id == uuid }
        }
        // Remove from knownDevices
        knownDevices.removeAll { $0.identifier == id }
        saveKnownDevices()
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
            // Ensure UI updates are made on the main thread
            DispatchQueue.main.async {
                self.isScanning = false
                self.lastError = BLEError.bluetoothPoweredOff
            }
            
        case .unauthorized:
            logger.error("Bluetooth permission not granted")
            DispatchQueue.main.async {
                self.lastError = BLEError.bluetoothUnauthorized
            }
            
        case .unsupported:
            logger.error("Bluetooth is not supported on this device")
            DispatchQueue.main.async {
                self.lastError = BLEError.bluetoothUnsupported
            }
            
        case .resetting:
            logger.warning("Bluetooth connection is being reset")
            
        case .unknown:
            logger.warning("Bluetooth status unknown")
            
        @unknown default:
            logger.warning("Unknown Bluetooth status")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Filter: Only allow even g1 glasses
        guard isEvenG1Device(peripheral: peripheral, advertisementData: advertisementData) else {
            return
        }
        
        // Ensure UI updates are made on the main thread
        DispatchQueue.main.async {
            // Check if the device has already been discovered
            if !self.discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                self.logger.info("New G1 device found: \(peripheral.name ?? "Unknown"), RSSI: \(RSSI.intValue) dBm")
                self.discoveredPeripherals.append(peripheral)
            }
            
            // Update RSSI for connected devices
            if let index = self.connectedDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
                self.connectedDevices[index].rssi = RSSI.intValue
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to device: \(peripheral.name ?? "Unknown")")
        
        // Ensure UI updates are made on the main thread
        DispatchQueue.main.async {
            // Update the device status
            if let index = self.connectedDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
                self.connectedDevices[index].isConnected = true
                self.connectedDevices[index].isConnecting = false
                
                // Aktualisiere das KnownDevice
                if let knownDeviceIndex = self.knownDevices.firstIndex(where: { $0.identifier == peripheral.identifier.uuidString }) {
                    self.knownDevices[knownDeviceIndex].lastConnected = Date()
                    self.saveKnownDevices()
                }
                
                // Create a session for the device
                let deviceId = self.connectedDevices[index].id
                let session = BLEDeviceSession(peripheral: peripheral, deviceId: deviceId)
                self.deviceSessions[deviceId] = session
                
                // Start the session
                session.start(with: self.activeProfile)
                
                // Stop scanning when we're connected
                if self.isScanning {
                    self.stopScan()
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Connection to device failed: \(peripheral.name ?? "Unknown"), Error: \(error?.localizedDescription ?? "Unknown")")
        
        // Ensure UI updates are made on the main thread
        DispatchQueue.main.async {
            // Update the device status
            if let index = self.connectedDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
                self.connectedDevices[index].isConnected = false
                self.connectedDevices[index].isConnecting = false
                self.connectedDevices[index].lastError = error
                
                // Remove the device from the list
                self.connectedDevices.remove(at: index)
            }
            
            self.lastError = error ?? BLEError.connectionFailed
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected from device: \(peripheral.name ?? "Unknown")")
        
        // Capture peripheral in a strong reference to prevent deallocation
        var peripheralRef = peripheral
        
        // Ensure UI updates are made on the main thread
        DispatchQueue.main.async {
            // Update the device status
            if let index = self.connectedDevices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) {
                self.connectedDevices[index].isConnected = false
                self.connectedDevices[index].isConnecting = false
                
                // Save device ID before removing
                let deviceId = self.connectedDevices[index].id
                
                // Keep peripheral reference in connectedDevices if we plan to reconnect
                if let error = error,
                   let knownDevice = self.knownDevices.first(where: { $0.identifier == peripheral.identifier.uuidString }),
                   knownDevice.autoReconnect {
                    // Just update status but don't remove
                } else {
                    self.connectedDevices.remove(at: index)
                    // Remove the session safely
                    self.deviceSessions[deviceId] = nil
                }
            }
            
            // Try to automatically reconnect if an error occurred
            if let error = error,
               let knownDevice = self.knownDevices.first(where: { $0.identifier == peripheral.identifier.uuidString }),
               knownDevice.autoReconnect {
                self.logger.info("Attempting to automatically reconnect: \(peripheralRef.name ?? "Unknown")")
                self.centralManager.connect(peripheralRef, options: nil)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        logger.info("Restoring BLE state")
        
        // Restoration of peripherals
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                logger.info("Restoring device: \(peripheral.name ?? "Unknown")")
                
                // Ensure UI updates are made on the main thread
                DispatchQueue.main.async {
                    // Check if the device is known
                    if let knownDevice = self.knownDevices.first(where: { $0.identifier == peripheral.identifier.uuidString }) {
                        // Create DeviceStatus and add it to the list
                        let deviceStatus = BLEDeviceStatus(knownDevice: knownDevice, peripheral: peripheral)
                        deviceStatus.isConnecting = true
                        self.connectedDevices.append(deviceStatus)
                        
                        // Reconnect to the device
                        self.centralManager.connect(peripheral, options: nil)
                    }
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
    case characteristicNotWritable
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
        case .characteristicNotWritable:
            return "BLE characteristic is not writable"
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

// Note: BLEDeviceStatus is not declared in this file.
// The requested computed property should be added in the BLEDeviceStatus definition file:
//
// var name: String {
//     return peripheral?.name ?? knownDevice?.name ?? "Unknown"
// }

