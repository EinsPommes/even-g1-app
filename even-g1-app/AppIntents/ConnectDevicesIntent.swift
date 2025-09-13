//
//  ConnectDevicesIntent.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import AppIntents
import SwiftUI

/// Intent to connect to known G1 glasses
struct ConnectDevicesIntent: AppIntent {
    static var title: LocalizedStringResource = "Connect to G1 Glasses"
    static var description: IntentDescription = IntentDescription("Connects to known G1 glasses")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Connect to G1 glasses") {
            \.$deviceRole
            \.$waitForConnection
        }
    }
    
    @Parameter(title: "Device Type", description: "Which glasses to connect to")
    var deviceRole: DeviceRoleEnum?
    
    @Parameter(title: "Wait for Connection", description: "Wait until the connection is established")
    var waitForConnection: Bool?
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let bleManager = BLEManager()
        
        // Load known devices
        let knownDevices = bleManager.knownDevices
        
        if knownDevices.isEmpty {
            return .result(dialog: "No known G1 glasses found. Please connect the glasses in the app first.")
        }
        
        // Filter by role if specified
        let devicesToConnect: [KnownDevice]
        
        if let roleEnum = deviceRole {
            let role = DeviceRole(rawValue: roleEnum.rawValue) ?? .unknown
            devicesToConnect = knownDevices.filter { $0.role == role }
            
            if devicesToConnect.isEmpty {
                return .result(dialog: "No known \(role.rawValue) glasses found.")
            }
        } else {
            devicesToConnect = knownDevices
        }
        
        // Connect to devices
        await bleManager.reconnectSavedDevices()
        
        // Wait for connection if requested
        if waitForConnection == true {
            // Wait max 10 seconds
            for _ in 0..<10 {
                if !bleManager.connectedDevices.isEmpty {
                    break
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
            if bleManager.connectedDevices.isEmpty {
                return .result(dialog: "Could not establish connection to G1 glasses.")
            }
        }
        
        let connectedCount = bleManager.connectedDevices.count
        return .result(dialog: "Connected to \(connectedCount) G1 glasses.")
    }
}

// MARK: - Device Role Enum

/// Enum for device roles in App Intents
enum DeviceRoleEnum: String, AppEnum {
    case left = "Left"
    case right = "Right"
    case unknown = "Unknown"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Glasses Type")
    
    static var caseDisplayRepresentations: [DeviceRoleEnum: DisplayRepresentation] = [
        .left: DisplayRepresentation(title: "Left Glasses"),
        .right: DisplayRepresentation(title: "Right Glasses"),
        .unknown: DisplayRepresentation(title: "All Glasses")
    ]
}
