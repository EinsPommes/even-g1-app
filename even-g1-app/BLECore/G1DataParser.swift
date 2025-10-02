//
//  G1DataParser.swift
//  even-g1-app
//
//  Created by oxo.mika on 02/10/2025.
//

import Foundation
import OSLog

/// Class for parsing data packets from G1 glasses
class G1DataParser {
    private let logger = Logger(subsystem: "com.g1teleprompter", category: "G1DataParser")
    
    // MARK: - Public Methods
    
    /// Parse a data packet received from G1 glasses
    /// - Parameter data: The raw data received from the glasses
    /// - Returns: A parsed G1DataPacket if successful, nil otherwise
    func parsePacket(_ data: Data) -> G1DataPacket? {
        guard !data.isEmpty else {
            logger.error("Empty data packet received")
            return nil
        }
        
        // Log the raw data for debugging
        logger.debug("Parsing data packet: \(data.hexString)")
        
        // Check for minimum packet size
        guard data.count >= 2 else {
            logger.error("Data packet too small: \(data.count) bytes")
            return nil
        }
        
        // Extract packet type from first byte
        let packetType = data[0]
        
        switch packetType {
        case 0x22: // Command packet
            return parseCommandPacket(data)
        case 0x29: // Status packet
            return parseStatusPacket(data)
        case 0x2B: // Heartbeat packet
            return parseHeartbeatPacket(data)
        case 0x2C: // Battery packet
            return parseBatteryPacket(data)
        case 0x06: // Configuration packet
            return parseConfigPacket(data)
        case 0xF1: // Data stream packet
            return parseDataStreamPacket(data)
        case 0xF5: // Event packet
            return parseEventPacket(data)
        case 0x48: // Response to text message
            return parseResponsePacket(data)
        default:
            logger.warning("Unknown packet type: \(String(format: "0x%02X", packetType))")
            return G1DataPacket(type: .unknown, rawData: data, payload: [:])
        }
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseCommandPacket(_ data: Data) -> G1DataPacket {
        guard data.count >= 3 else {
            return G1DataPacket(type: .command, rawData: data, payload: [:])
        }
        
        let length = Int(data[1])
        let commandId = data[2]
        
        var payload: [String: Any] = [
            "commandId": commandId,
            "length": length
        ]
        
        // Extract command data if available
        if data.count > 3 {
            let commandData = data.subdata(in: 3..<data.count)
            payload["commandData"] = commandData
        }
        
        return G1DataPacket(type: .command, rawData: data, payload: payload)
    }
    
    private func parseStatusPacket(_ data: Data) -> G1DataPacket {
        guard data.count >= 3 else {
            return G1DataPacket(type: .status, rawData: data, payload: [:])
        }
        
        let statusType = data[1]
        let statusValue = data[2]
        
        let payload: [String: Any] = [
            "statusType": statusType,
            "statusValue": statusValue
        ]
        
        return G1DataPacket(type: .status, rawData: data, payload: payload)
    }
    
    private func parseHeartbeatPacket(_ data: Data) -> G1DataPacket {
        guard data.count >= 3 else {
            return G1DataPacket(type: .heartbeat, rawData: data, payload: [:])
        }
        
        let heartbeatId = data[1]
        let heartbeatValue = data[2]
        
        let payload: [String: Any] = [
            "heartbeatId": heartbeatId,
            "heartbeatValue": heartbeatValue
        ]
        
        return G1DataPacket(type: .heartbeat, rawData: data, payload: payload)
    }
    
    private func parseBatteryPacket(_ data: Data) -> G1DataPacket {
        guard data.count >= 6 else {
            return G1DataPacket(type: .battery, rawData: data, payload: [:])
        }
        
        let batteryId = data[1]
        let batteryLevel = data[2]
        let timestamp = data[3..<6]
        
        let payload: [String: Any] = [
            "batteryId": batteryId,
            "batteryLevel": batteryLevel,
            "timestamp": timestamp
        ]
        
        return G1DataPacket(type: .battery, rawData: data, payload: payload)
    }
    
    private func parseConfigPacket(_ data: Data) -> G1DataPacket {
        guard data.count >= 3 else {
            return G1DataPacket(type: .config, rawData: data, payload: [:])
        }
        
        let configLength = Int(data[1])
        let configId = data[2]
        
        var payload: [String: Any] = [
            "configId": configId,
            "configLength": configLength
        ]
        
        // Extract config data if available
        if data.count > 3 {
            let configData = data.subdata(in: 3..<data.count)
            payload["configData"] = configData
        }
        
        return G1DataPacket(type: .config, rawData: data, payload: payload)
    }
    
    private func parseDataStreamPacket(_ data: Data) -> G1DataPacket {
        guard data.count >= 3 else {
            return G1DataPacket(type: .dataStream, rawData: data, payload: [:])
        }
        
        let streamId = data[1]
        
        var payload: [String: Any] = [
            "streamId": streamId
        ]
        
        // Extract stream data if available
        if data.count > 2 {
            let streamData = data.subdata(in: 2..<data.count)
            payload["streamData"] = streamData
        }
        
        return G1DataPacket(type: .dataStream, rawData: data, payload: payload)
    }
    
    private func parseEventPacket(_ data: Data) -> G1DataPacket {
        guard data.count >= 3 else {
            return G1DataPacket(type: .event, rawData: data, payload: [:])
        }
        
        let eventId = data[1]
        
        var payload: [String: Any] = [
            "eventId": eventId
        ]
        
        // Extract event data if available
        if data.count > 2 {
            let eventData = data.subdata(in: 2..<data.count)
            payload["eventData"] = eventData
        }
        
        return G1DataPacket(type: .event, rawData: data, payload: payload)
    }
    
    private func parseResponsePacket(_ data: Data) -> G1DataPacket {
        guard data.count >= 3 else {
            return G1DataPacket(type: .response, rawData: data, payload: [:])
        }
        
        // Check for error response
        if data.count >= 4 && data[1] == 0xCA {
            // This is an error response
            let errorMessage: String
            if data.count > 4 {
                let errorData = data.subdata(in: 2..<(data.count - 2)) // Remove trailing zeros
                errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            } else {
                errorMessage = "Unknown error"
            }
            
            let payload: [String: Any] = [
                "isError": true,
                "errorMessage": errorMessage
            ]
            
            return G1DataPacket(type: .response, rawData: data, payload: payload)
        } else {
            // Regular response
            let responseData = data.subdata(in: 1..<data.count)
            let responseText = String(data: responseData, encoding: .utf8) ?? ""
            
            let payload: [String: Any] = [
                "isError": false,
                "responseText": responseText
            ]
            
            return G1DataPacket(type: .response, rawData: data, payload: payload)
        }
    }
}

/// Represents a parsed data packet from G1 glasses
struct G1DataPacket {
    enum PacketType {
        case command
        case status
        case heartbeat
        case battery
        case config
        case dataStream
        case event
        case response
        case unknown
    }
    
    let type: PacketType
    let rawData: Data
    let payload: [String: Any]
    
    var description: String {
        var desc = "G1DataPacket: \(type)"
        
        switch type {
        case .command:
            if let commandId = payload["commandId"] as? UInt8 {
                desc += " - Command ID: \(String(format: "0x%02X", commandId))"
            }
        case .status:
            if let statusType = payload["statusType"] as? UInt8,
               let statusValue = payload["statusValue"] as? UInt8 {
                desc += " - Status: \(String(format: "0x%02X", statusType)) = \(String(format: "0x%02X", statusValue))"
            }
        case .heartbeat:
            if let heartbeatValue = payload["heartbeatValue"] as? UInt8 {
                desc += " - Heartbeat: \(heartbeatValue)"
            }
        case .battery:
            if let batteryLevel = payload["batteryLevel"] as? UInt8 {
                desc += " - Battery: \(batteryLevel)%"
            }
        case .response:
            if let isError = payload["isError"] as? Bool, isError,
               let errorMessage = payload["errorMessage"] as? String {
                desc += " - Error: \(errorMessage)"
            } else if let responseText = payload["responseText"] as? String {
                desc += " - Response: \(responseText)"
            }
        default:
            break
        }
        
        return desc
    }
}

// Note: Using hexString extension from DataExtension.swift
