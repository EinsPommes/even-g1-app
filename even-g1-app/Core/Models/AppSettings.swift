//
//  AppSettings.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation

// Persistent app settings
struct AppSettings: Codable, Equatable {
    // BLE settings
    var activeProfileId: UUID?
    var autoReconnect: Bool = true
    var scanTimeout: TimeInterval = 10.0
    
    // Teleprompter settings
    var defaultScrollSpeed: Double = 1.0
    var fontSizeMultiplier: Double = 1.0
    var lineSpacing: Double = 1.2
    var usesMonospaceFont: Bool = false
    var showCountdown: Bool = true
    var countdownDuration: TimeInterval = 3.0
    
    // General settings
    var useCloudSync: Bool = true
    var useDarkMode: Bool? = nil // nil = system setting
    var enableVoiceInput: Bool = true
    var enableBackgroundMode: Bool = true
    var enableWidgets: Bool = true
    var enableLiveActivity: Bool = true
    
    // Diagnostic settings
    var verboseLogging: Bool = false
    var logRetentionDays: Int = 7
    
    // Persistence
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "AppSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "AppSettings")
        }
    }
}
