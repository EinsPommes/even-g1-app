//
//  BLEDeviceSession.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import CoreBluetooth
import Combine
import OSLog

// Manages an active session with a BLE device
class BLEDeviceSession: NSObject {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.g1teleprompter", category: "BLEDeviceSession")
    private let peripheral: CBPeripheral
    private let deviceId: UUID
    
    private var profile: ProtocolProfile?
    private var services: [CBUUID: CBService] = [:]
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    
    private var pendingRequests: [UUID: (Result<Data?, Error>) -> Void] = [:]
    private var notificationSubjects: [CBUUID: PassthroughSubject<Data, Error>] = [:]
    
    // MARK: - Initialization
    
    init(peripheral: CBPeripheral, deviceId: UUID) {
        self.peripheral = peripheral
        self.deviceId = deviceId
        super.init()
        self.peripheral.delegate = self
    }
    
    // MARK: - Public Methods
    
    // Starts the session and discovers services and characteristics
    func start(with profile: ProtocolProfile?) {
        self.profile = profile
        peripheral.discoverServices(nil) // Discover all services
    }
    
    // Updates the protocol profile
    func updateProfile(_ profile: ProtocolProfile) {
        self.profile = profile
    }
    
    /// Writes data to the TX characteristic
    func writeData(_ text: String, using profile: ProtocolProfile) async throws {
        // Create CBUUIDs from strings
        let serviceUUID = CBUUID(string: profile.serviceUUID)
        let txUUID = CBUUID(string: profile.txCharacteristic)
        
        // Check if services and characteristics exist
        guard let service = services[serviceUUID],
              let characteristic = characteristics[txUUID] else {
            throw BLEError.characteristicNotFound
        }
        
        // Encode text according to profile
        guard let data = encodeData(text, using: profile) else {
            throw BLEError.encodingError
        }
        
        // Check if we need to fragment the data
        if let framing = profile.framing, let maxSize = framing.maxPacketSize, data.count > maxSize {
            // Fragment the data
            try await sendFragmentedData(data, characteristic: characteristic, writeType: profile.writeType.cbWriteType, framing: framing)
        } else {
            // Send data directly
            try await withCheckedThrowingContinuation { continuation in
                writeData(data, to: characteristic, type: profile.writeType.cbWriteType) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Reads data from a characteristic
    func readData(from characteristicUUID: CBUUID) async throws -> Data? {
        guard let characteristic = characteristics[characteristicUUID] else {
            throw BLEError.characteristicNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let requestId = UUID()
            pendingRequests[requestId] = { result in
                self.pendingRequests.removeValue(forKey: requestId)
                continuation.resume(with: result)
            }
            
            peripheral.readValue(for: characteristic)
        }
    }
    
    /// Subscribes to notifications from a characteristic
    func subscribeToNotifications(from characteristicUUID: CBUUID) -> AnyPublisher<Data, Error>? {
        guard let characteristic = characteristics[characteristicUUID] else {
            return nil
        }
        
        // Create a subject if it doesn't exist yet
        if notificationSubjects[characteristicUUID] == nil {
            notificationSubjects[characteristicUUID] = PassthroughSubject<Data, Error>()
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        return notificationSubjects[characteristicUUID]?.eraseToAnyPublisher()
    }
    
    /// Unsubscribes from notifications
    func unsubscribeFromNotifications(from characteristicUUID: CBUUID) {
        guard let characteristic = characteristics[characteristicUUID] else {
            return
        }
        
        peripheral.setNotifyValue(false, for: characteristic)
        notificationSubjects.removeValue(forKey: characteristicUUID)
    }
    
    // MARK: - Private Methods
    
    private func encodeData(_ text: String, using profile: ProtocolProfile) -> Data? {
        switch profile.encoding {
        case .utf8:
            return text.data(using: .utf8)
            
        case .hex:
            // Convert hex string to data
            var data = Data()
            var hexString = text
            
            // Remove spaces and other separators
            hexString = hexString.replacingOccurrences(of: " ", with: "")
            hexString = hexString.replacingOccurrences(of: "<", with: "")
            hexString = hexString.replacingOccurrences(of: ">", with: "")
            hexString = hexString.replacingOccurrences(of: "0x", with: "")
            
            // Ensure length is even
            if hexString.count % 2 != 0 {
                hexString = "0" + hexString
            }
            
            // Convert each pair of characters to a byte
            var i = hexString.startIndex
            while i < hexString.endIndex {
                let nextIndex = hexString.index(i, offsetBy: 2)
                let byteString = hexString[i..<nextIndex]
                if let byte = UInt8(byteString, radix: 16) {
                    data.append(byte)
                } else {
                    return nil
                }
                i = nextIndex
            }
            
            return data
            
        case .bytes:
            // For byte arrays, we expect a comma-separated list of numbers
            let byteStrings = text.split(separator: ",")
            var data = Data()
            
            for byteString in byteStrings {
                if let byte = UInt8(byteString.trimmingCharacters(in: .whitespaces)) {
                    data.append(byte)
                } else {
                    return nil
                }
            }
            
            return data
        }
    }
    
    private func sendFragmentedData(_ data: Data, characteristic: CBCharacteristic, writeType: CBCharacteristicWriteType, framing: Framing) async throws {
        let maxSize = framing.maxPacketSize ?? 20 
        var offset = 0
        
        while offset < data.count {
            let endIndex = min(offset + maxSize, data.count)
            let chunk = data.subdata(in: offset..<endIndex)
            
            var packetData = Data()
            
            // Add start bytes if available
            if let startBytes = framing.startBytes, offset == 0 {
                packetData.append(startBytes)
            }
            
            // Add chunk data
            packetData.append(chunk)
            
            // Add end bytes if available
            if let endBytes = framing.endBytes, endIndex == data.count {
                packetData.append(endBytes)
            }
            
            // Send the packet
            try await withCheckedThrowingContinuation { continuation in
                writeData(packetData, to: characteristic, type: writeType) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Wait briefly between packets to avoid overload
            if endIndex < data.count {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            offset = endIndex
        }
    }
    
    private func writeData(_ data: Data, to characteristic: CBCharacteristic, type: CBCharacteristicWriteType, completion: @escaping (Result<Void, Error>) -> Void) {
        let requestId = UUID()
        
        if type == .withResponse {
            pendingRequests[requestId] = { result in
                self.pendingRequests.removeValue(forKey: requestId)
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            // With withoutResponse there is no confirmation
            completion(.success(()))
        }
        
        peripheral.writeValue(data, for: characteristic, type: type)
        
        // Log der gesendeten Daten
        logger.debug("Daten gesendet: \(data.hexString)")
    }
}

// MARK: - CBPeripheralDelegate

extension BLEDeviceSession: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            logger.warning("No services found")
            return
        }
        
        logger.info("Services discovered: \(services.count)")
        
        // Store services and discover characteristics
        for service in services {
            self.services[service.uuid] = service
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger.error("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            logger.warning("No characteristics found for service: \(service.uuid)")
            return
        }
        
        logger.info("Characteristics discovered for service \(service.uuid): \(characteristics.count)")
        
        // Store characteristics
        for characteristic in characteristics {
            self.characteristics[characteristic.uuid] = characteristic
            
            // Log the properties
            var properties: [String] = []
            if characteristic.properties.contains(.read) { properties.append("Read") }
            if characteristic.properties.contains(.write) { properties.append("Write") }
            if characteristic.properties.contains(.writeWithoutResponse) { properties.append("WriteWithoutResponse") }
            if characteristic.properties.contains(.notify) { properties.append("Notify") }
            if characteristic.properties.contains(.indicate) { properties.append("Indicate") }
            
            logger.debug("Characteristic: \(characteristic.uuid), Properties: \(properties.joined(separator: ", "))")
            
            // Subscribe to notifications for RX characteristic if available
            if let profile = profile,
               let rxUUID = profile.rxCharacteristic.flatMap({ CBUUID(string: $0) }),
               characteristic.uuid == rxUUID && characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error reading characteristic: \(error.localizedDescription)")
            
            // Notify all waiting requests about the error
            for (_, completion) in pendingRequests {
                completion(.failure(error))
            }
            pendingRequests.removeAll()
            
            // Notify subscribers about the error
            notificationSubjects[characteristic.uuid]?.send(completion: .failure(error))
            
            return
        }
        
        guard let value = characteristic.value else {
            logger.warning("Empty value for characteristic: \(characteristic.uuid)")
            return
        }
        
        logger.debug("Data received: \(value.hexString)")
        
        // Notify waiting requests
        for (_, completion) in pendingRequests {
            completion(.success(value))
        }
        pendingRequests.removeAll()
        
        // Benachrichtige Abonnenten
        notificationSubjects[characteristic.uuid]?.send(value)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error writing to characteristic: \(error.localizedDescription)")
            
            // Notify all waiting requests about the error
            for (_, completion) in pendingRequests {
                completion(.failure(error))
            }
            pendingRequests.removeAll()
            
            return
        }
        
        logger.debug("Daten erfolgreich geschrieben an: \(characteristic.uuid)")
        
        // Notify waiting requests
        for (_, completion) in pendingRequests {
            completion(.success(nil))
        }
        pendingRequests.removeAll()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error with notifications for characteristic: \(error.localizedDescription)")
            notificationSubjects[characteristic.uuid]?.send(completion: .failure(error))
            return
        }
        
        if characteristic.isNotifying {
            logger.debug("Notifications enabled for: \(characteristic.uuid)")
        } else {
            logger.debug("Notifications disabled for: \(characteristic.uuid)")
            notificationSubjects[characteristic.uuid]?.send(completion: .finished)
            notificationSubjects.removeValue(forKey: characteristic.uuid)
        }
    }
}

// MARK: - End of BLEDeviceSession
