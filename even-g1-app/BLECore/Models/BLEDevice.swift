//
//  BLEDevice.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import CoreBluetooth

// Device role (left/right/unknown)
enum DeviceRole: String, Codable, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"
    case unknown = "Unknown"
    
    var id: String { self.rawValue }
}

// Stored information about a known BLE device
struct KnownDevice: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var role: DeviceRole
    var identifier: String // CBPeripheral identifier
    var autoReconnect: Bool
    var lastConnected: Date?
    var customName: String?
    
    var displayName: String {
        return customName ?? name
    }
    
    init(id: UUID = UUID(), name: String, role: DeviceRole = .unknown, 
         identifier: String, autoReconnect: Bool = true, lastConnected: Date? = nil, 
         customName: String? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.identifier = identifier
        self.autoReconnect = autoReconnect
        self.lastConnected = lastConnected
        self.customName = customName
    }
    
    init(from peripheral: CBPeripheral, role: DeviceRole = .unknown) {
        self.id = UUID()
        self.name = peripheral.name ?? "Unknown Device"
        self.role = role
        self.identifier = peripheral.identifier.uuidString
        self.autoReconnect = true
    }
}

// Active BLE device status with live data
class BLEDeviceStatus: ObservableObject, Identifiable {
    let id: UUID
    let knownDevice: KnownDevice
    
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var rssi: Int = 0
    @Published var batteryLevel: Int? = nil
    @Published var lastError: Error? = nil
    
    // Reference to CoreBluetooth peripheral
    var peripheral: CBPeripheral?
    
    init(knownDevice: KnownDevice, peripheral: CBPeripheral? = nil) {
        self.id = knownDevice.id
        self.knownDevice = knownDevice
        self.peripheral = peripheral
    }
}

// Protocol profile for BLE communication
struct ProtocolProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var serviceUUID: String
    var txCharacteristic: String
    var rxCharacteristic: String?
    var writeType: WriteType
    var encoding: DataEncoding
    var framing: Framing?
    var commands: [String: CommandTemplate]
    
    init(id: UUID = UUID(), name: String, serviceUUID: String, txCharacteristic: String, 
         rxCharacteristic: String? = nil, writeType: WriteType = .withResponse, 
         encoding: DataEncoding = .utf8, framing: Framing? = nil, 
         commands: [String: CommandTemplate] = [:]) {
        self.id = id
        self.name = name
        self.serviceUUID = serviceUUID
        self.txCharacteristic = txCharacteristic
        self.rxCharacteristic = rxCharacteristic
        self.writeType = writeType
        self.encoding = encoding
        self.framing = framing
        self.commands = commands
    }
    
    static var defaultProfile: ProtocolProfile {
        return ProtocolProfile(
            name: "Standard G1 Profile",
            serviceUUID: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E", // Example UUID
            txCharacteristic: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E", // Example UUID
            rxCharacteristic: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E", // Example UUID
            writeType: .withoutResponse,
            encoding: .utf8,
            commands: [
                "SEND_TEXT": CommandTemplate(
                    template: "{text}",
                    description: "Send text to glasses"
                ),
                "CLEAR": CommandTemplate(
                    template: "CLEAR",
                    description: "Clear display"
                )
            ]
        )
    }
}

/// Write mode for BLE characteristic
enum WriteType: String, Codable, CaseIterable, Identifiable {
    case withResponse = "With Response"
    case withoutResponse = "Without Response"
    
    var id: String { self.rawValue }
    
    var cbWriteType: CBCharacteristicWriteType {
        switch self {
        case .withResponse:
            return .withResponse
        case .withoutResponse:
            return .withoutResponse
        }
    }
}

/// Data encoding for BLE communication
enum DataEncoding: String, Codable, CaseIterable, Identifiable {
    case utf8 = "UTF-8 Text"
    case hex = "Hexadecimal"
    case bytes = "Byte-Array"
    
    var id: String { self.rawValue }
}

/// Optional framing for BLE messages
struct Framing: Codable, Hashable {
    var startBytes: Data?
    var endBytes: Data?
    var maxPacketSize: Int?
    
    init(startBytes: Data? = nil, endBytes: Data? = nil, maxPacketSize: Int? = nil) {
        self.startBytes = startBytes
        self.endBytes = endBytes
        self.maxPacketSize = maxPacketSize
    }
}

/// Template for BLE commands with placeholders
struct CommandTemplate: Codable, Hashable {
    var template: String
    var description: String
    
    init(template: String, description: String) {
        self.template = template
        self.description = description
    }
    
    /// Replaces placeholders in the template
    func format(with parameters: [String: String]) -> String {
        var result = template
        for (key, value) in parameters {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
