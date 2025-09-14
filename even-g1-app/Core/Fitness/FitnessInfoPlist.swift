//
//  FitnessInfoPlist.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import os.log

/// Helper class to programmatically add HealthKit permissions to Info.plist
class FitnessInfoPlist {
    private static let logger = Logger(subsystem: "com.evenreality.g1-teleprompter", category: "FitnessInfoPlist")
    
    /// Adds HealthKit permissions to Info.plist
    static func addHealthKitPermissions() {
        // Add HealthKit usage descriptions
        addInfoPlistKey("NSHealthShareUsageDescription", value: "This app needs access to your health data to display fitness metrics and send them to your G1 glasses.")
        addInfoPlistKey("NSHealthUpdateUsageDescription", value: "This app needs permission to save workout data to your Health app.")
        
        logger.info("Added HealthKit permissions to Info.plist")
    }
    
    /// Adds a key-value pair to Info.plist
    private static func addInfoPlistKey(_ key: String, value: String) {
        guard let infoPlistPath = Bundle.main.path(forResource: "Info", ofType: "plist") else {
            // If Info.plist doesn't exist, we need to use the programmatic approach
            addInfoPlistKeyProgrammatically(key, value: value)
            return
        }
        
        // If Info.plist exists, try to modify it directly
        do {
            let infoPlistUrl = URL(fileURLWithPath: infoPlistPath)
            var infoPlistDict = try NSDictionary(contentsOf: infoPlistUrl, error: ()) as? [String: Any] ?? [:]
            
            // Only add if not already present
            if infoPlistDict[key] == nil {
                infoPlistDict[key] = value
                try (infoPlistDict as NSDictionary).write(to: infoPlistUrl)
                logger.info("Added \(key) to Info.plist")
            }
        } catch {
            logger.error("Error modifying Info.plist: \(error.localizedDescription)")
            addInfoPlistKeyProgrammatically(key, value: value)
        }
    }
    
    /// Adds a key-value pair to Info.plist programmatically (when direct file access fails)
    private static func addInfoPlistKeyProgrammatically(_ key: String, value: String) {
        // Set the value programmatically for the current session
        // This is a fallback and won't persist between app launches
        if let infoDictionary = Bundle.main.infoDictionary as? NSMutableDictionary {
            if infoDictionary[key] == nil {
                infoDictionary[key] = value
                logger.info("Added \(key) programmatically (temporary)")
            }
        }
        
        logger.warning("Info.plist modifications are temporary and won't persist between app launches")
    }
}
