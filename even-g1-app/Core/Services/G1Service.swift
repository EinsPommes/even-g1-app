//
//  G1Service.swift
//  even-g1-app
//
//  Created by oxo.mika on 02/10/2025.
//

import Foundation
import Combine
import CoreBluetooth
import OSLog

/// Service status codes
enum G1ServiceStatus: Int {
    case ready = 0
    case looking = 1
    case looked = 2
    case error = 3
}

/// Connection state codes
enum G1ConnectionState: Int {
    case uninitialized = 0
    case disconnected = 1
    case connecting = 2
    case connected = 3
    case disconnecting = 4
    case error = 5
}

/// Represents a pair of G1 glasses
struct G1Glasses: Identifiable, Equatable {
    var id: String // Unique ID based on device MAC
    var name: String
    var connectionState: G1ConnectionState
    var batteryPercentage: Int
    
    static func == (lhs: G1Glasses, rhs: G1Glasses) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Current state of the G1 service
struct G1ServiceState {
    static let READY = 0
    static let LOOKING = 1
    static let LOOKED = 2
    static let ERROR = 3
    
    var status: Int
    var glasses: [G1Glasses]
}

/// Service that manages G1 glasses connections
class G1Service: ObservableObject {
    private let logger = Logger(subsystem: "com.g1teleprompter", category: "G1Service")
    private var bleManager = BLEManager()
    private var cancellables = Set<AnyCancellable>()
    
    // Published state
    @Published private(set) var state = G1ServiceState(status: G1ServiceState.READY, glasses: [])
    
    // Scan timeout
    private var scanTimer: Timer?
    private var scanTimeout: TimeInterval = 15
    
    init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Monitor BLE state changes
        bleManager.$centralState
            .sink { [weak self] state in
                self?.updateServiceState()
            }
            .store(in: &cancellables)
        
        // Monitor discovered and connected devices
        Publishers.CombineLatest(bleManager.$discoveredPeripherals, bleManager.$connectedDevices)
            .sink { [weak self] (discovered, connected) in
                self?.updateGlassesList(discovered: discovered, connected: connected)
            }
            .store(in: &cancellables)
    }
    
    private func updateServiceState() {
        if bleManager.isScanning {
            state.status = G1ServiceState.LOOKING
        } else if bleManager.centralState != .poweredOn {
            state.status = G1ServiceState.ERROR
        } else {
            state.status = G1ServiceState.READY
        }
    }
    
    private func updateGlassesList(discovered: [CBPeripheral], connected: [BLEDeviceStatus]) {
        var glassesList: [G1Glasses] = []
        
        // Add connected devices
        for device in connected {
            let connectionState: G1ConnectionState = {
                if device.isConnecting {
                    return .connecting
                } else if device.isConnected {
                    return .connected
                } else {
                    return .disconnected
                }
            }()
            
            let glasses = G1Glasses(
                id: device.id.uuidString,
                name: device.name,
                connectionState: connectionState,
                batteryPercentage: device.batteryLevel ?? 0
            )
            glassesList.append(glasses)
        }
        
        // Add discovered but not connected devices
        for peripheral in discovered {
            // Skip if already in the list
            if glassesList.contains(where: { $0.id == peripheral.identifier.uuidString }) {
                continue
            }
            
            let glasses = G1Glasses(
                id: peripheral.identifier.uuidString,
                name: peripheral.name ?? "Unknown G1",
                connectionState: .disconnected,
                batteryPercentage: 0
            )
            glassesList.append(glasses)
        }
        
        state.glasses = glassesList
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for G1 glasses
    func lookForGlasses() {
        guard bleManager.centralState == .poweredOn else {
            logger.warning("Cannot scan: Bluetooth not powered on")
            state.status = G1ServiceState.ERROR
            return
        }
        
        // Start scanning
        bleManager.startScan()
        state.status = G1ServiceState.LOOKING
        
        // Set timeout
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanTimeout, repeats: false) { [weak self] _ in
            self?.bleManager.stopScan()
            self?.state.status = G1ServiceState.LOOKED
        }
    }
    
    /// Connect to G1 glasses
    func connect(id: String) async -> Bool {
        guard let uuid = UUID(uuidString: id) else {
            logger.error("Invalid glasses ID format")
            return false
        }
        
        // Find the peripheral
        if let peripheral = bleManager.discoveredPeripherals.first(where: { $0.identifier.uuidString == id }) {
            bleManager.connect(to: peripheral)
            
            // Wait for connection to complete
            for _ in 0..<10 { // Wait up to 5 seconds
                if bleManager.connectedDevices.contains(where: { 
                    $0.peripheral?.identifier.uuidString == id && $0.isConnected 
                }) {
                    return true
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        return false
    }
    
    /// Disconnect from G1 glasses
    func disconnect(id: String) {
        guard let uuid = UUID(uuidString: id) else {
            logger.error("Invalid glasses ID format")
            return
        }
        
        bleManager.disconnect(deviceId: uuid)
    }
    
    /// List all connected G1 glasses
    func listConnectedGlasses() -> [G1Glasses] {
        return state.glasses.filter { $0.connectionState == .connected }
    }
    
    /// Display text on G1 glasses
    func displayTextPage(id: String, page: [String]) async -> Bool {
        guard let uuid = UUID(uuidString: id),
              let text = formatTextPage(page) else {
            return false
        }
        
        let result = await bleManager.sendText(text, to: uuid)
        return result.isSuccess
    }
    
    /// Display text for a specific duration
    func displayTimedTextPage(id: String, page: [String], milliseconds: Int) async -> Bool {
        // First display the text
        let success = await displayTextPage(id: id, page: page)
        
        if success {
            // Schedule removal after the specified time
            Task {
                try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
                await stopDisplaying(id: id)
            }
        }
        
        return success
    }
    
    /// Display formatted text
    func displayFormattedPage(id: String, formattedPage: FormattedPage) async -> Bool {
        let textPage = formatFormattedPage(formattedPage)
        return await displayTextPage(id: id, page: textPage)
    }
    
    /// Display formatted text for a specific duration
    func displayTimedFormattedPage(id: String, timedFormattedPage: TimedFormattedPage) async -> Bool {
        let textPage = formatFormattedPage(timedFormattedPage.page)
        return await displayTimedTextPage(id: id, page: textPage, milliseconds: timedFormattedPage.milliseconds)
    }
    
    /// Display a sequence of formatted pages
    func displayFormattedPageSequence(id: String, sequence: [TimedFormattedPage]) async -> Bool {
        for timedPage in sequence {
            let success = await displayTimedFormattedPage(id: id, timedFormattedPage: timedPage)
            if !success {
                return false
            }
            
            // Wait for the duration before showing the next page
            try? await Task.sleep(nanoseconds: UInt64(timedPage.milliseconds) * 1_000_000)
        }
        return true
    }
    
    /// Display centered text
    func displayCentered(id: String, textLines: [String], milliseconds: Int? = 2000) async -> Bool {
        let formattedPage = FormattedPage.centered(textLines)
        
        if let ms = milliseconds {
            let timedPage = TimedFormattedPage(page: formattedPage, milliseconds: ms)
            return await displayTimedFormattedPage(id: id, timedFormattedPage: timedPage)
        } else {
            return await displayFormattedPage(id: id, formattedPage: formattedPage)
        }
    }
    
    /// Stop displaying text
    func stopDisplaying(id: String) async -> Bool {
        guard let uuid = UUID(uuidString: id) else {
            return false
        }
        
        // Use the CLEAR command if available in the active profile
        if let result = try? await bleManager.sendCommand("CLEAR", to: uuid) {
            return result.isSuccess
        } else {
            // Fallback: Send empty text
            let result = await bleManager.sendText("", to: uuid)
            return result.isSuccess
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTextPage(_ page: [String]) -> String? {
        // Validate input
        guard page.count <= 5 else {
            logger.error("Too many lines in text page: \(page.count)")
            return nil
        }
        
        for line in page {
            if line.count > 40 {
                logger.warning("Line exceeds 40 characters: \(line)")
                // Continue anyway, the device will truncate
            }
        }
        
        // Join lines with newlines
        return page.joined(separator: "\n")
    }
    
    private func formatFormattedPage(_ page: FormattedPage) -> [String] {
        var result: [String] = []
        
        // Process each line according to its justification
        for line in page.lines.prefix(5) {
            var formattedLine = line.text
            
            // Truncate if too long
            if formattedLine.count > 40 {
                formattedLine = String(formattedLine.prefix(40))
            }
            
            // Apply justification
            switch line.justify {
            case .left:
                // No change needed
                break
            case .right:
                let padding = max(0, 40 - formattedLine.count)
                formattedLine = String(repeating: " ", count: padding) + formattedLine
            case .center:
                let padding = max(0, 40 - formattedLine.count) / 2
                formattedLine = String(repeating: " ", count: padding) + formattedLine
            }
            
            result.append(formattedLine)
        }
        
        // Apply vertical justification by adding empty lines
        let lineCount = result.count
        if lineCount < 5 {
            let emptyLinesNeeded = 5 - lineCount
            
            switch page.justify {
            case .top:
                // Add empty lines at the bottom
                for _ in 0..<emptyLinesNeeded {
                    result.append("")
                }
            case .bottom:
                // Add empty lines at the top
                for _ in 0..<emptyLinesNeeded {
                    result.insert("", at: 0)
                }
            case .center:
                // Add empty lines at top and bottom
                let topPadding = emptyLinesNeeded / 2
                let bottomPadding = emptyLinesNeeded - topPadding
                
                for _ in 0..<topPadding {
                    result.insert("", at: 0)
                }
                
                for _ in 0..<bottomPadding {
                    result.append("")
                }
            }
        }
        
        return result
    }
}

// MARK: - Result Extension

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

// MARK: - BLEManager Extension

extension BLEManager {
    /// Send a command using the active profile
    func sendCommand(_ commandName: String, to deviceId: UUID) async throws -> Result<Void, Error> {
        guard let session = deviceSessions[deviceId],
              let activeProfile = activeProfile,
              let command = activeProfile.commands[commandName] else {
            return .failure(BLEError.noActiveSession)
        }
        
        try await session.writeData(command.template, using: activeProfile)
        return .success(())
    }
}
