//
//  AppSettings.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import SwiftUI

/// App settings model
class AppSettings: Codable, Equatable {
    // Teleprompter settings
    var defaultScrollSpeed: Double = 1.0
    var fontSizeMultiplier: Double = 1.0
    var lineSpacing: Double = 1.0
    var usesMonospaceFont: Bool = false
    var showCountdown: Bool = true
    var countdownDuration: TimeInterval = 3.0
    
    // Appearance settings
    var useDarkMode: Bool? = nil // nil = follow system
    
    // Connection settings
    var autoReconnect: Bool = true
    var scanTimeout: Double = 10.0
    var activeProfileId: UUID? = nil
    
    // Feature settings
    var enableVoiceInput: Bool = true
    var enableBackgroundMode: Bool = true
    var enableWidgets: Bool = true
    var enableLiveActivity: Bool = true
    var useCloudSync: Bool = true
    
    // Fitness settings
    var showFitnessMetricsOnGlasses: Bool = false
    var autoSendWorkoutUpdates: Bool = false
    var fitnessMetricsUpdateInterval: TimeInterval = 30.0 // seconds
    var selectedFitnessMetrics: [String] = ["heartRate", "steps", "calories"]
    
    // Diagnostic settings
    var verboseLogging: Bool = false
    var logRetentionDays: Int = 7
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case defaultScrollSpeed, fontSizeMultiplier, lineSpacing, usesMonospaceFont
        case showCountdown, countdownDuration, useDarkMode, autoReconnect, scanTimeout
        case activeProfileId, enableVoiceInput, enableBackgroundMode, enableWidgets
        case enableLiveActivity, useCloudSync, verboseLogging, logRetentionDays
        case showFitnessMetricsOnGlasses, autoSendWorkoutUpdates, fitnessMetricsUpdateInterval
        case selectedFitnessMetrics
    }
    
    // MARK: - Equatable
    
    static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        return lhs.defaultScrollSpeed == rhs.defaultScrollSpeed &&
               lhs.fontSizeMultiplier == rhs.fontSizeMultiplier &&
               lhs.lineSpacing == rhs.lineSpacing &&
               lhs.usesMonospaceFont == rhs.usesMonospaceFont &&
               lhs.showCountdown == rhs.showCountdown &&
               lhs.countdownDuration == rhs.countdownDuration &&
               lhs.useDarkMode == rhs.useDarkMode &&
               lhs.autoReconnect == rhs.autoReconnect &&
               lhs.scanTimeout == rhs.scanTimeout &&
               lhs.activeProfileId == rhs.activeProfileId &&
               lhs.enableVoiceInput == rhs.enableVoiceInput &&
               lhs.enableBackgroundMode == rhs.enableBackgroundMode &&
               lhs.enableWidgets == rhs.enableWidgets &&
               lhs.enableLiveActivity == rhs.enableLiveActivity &&
               lhs.useCloudSync == rhs.useCloudSync &&
               lhs.showFitnessMetricsOnGlasses == rhs.showFitnessMetricsOnGlasses &&
               lhs.autoSendWorkoutUpdates == rhs.autoSendWorkoutUpdates &&
               lhs.fitnessMetricsUpdateInterval == rhs.fitnessMetricsUpdateInterval &&
               lhs.selectedFitnessMetrics == rhs.selectedFitnessMetrics &&
               lhs.verboseLogging == rhs.verboseLogging &&
               lhs.logRetentionDays == rhs.logRetentionDays
    }
    
    // MARK: - Persistence
    
    /// Save settings to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "AppSettings")
        }
    }
    
    /// Load settings from UserDefaults
    static func load() -> AppSettings {
        if let data = UserDefaults.standard.data(forKey: "AppSettings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return settings
        }
        return AppSettings()
    }
}