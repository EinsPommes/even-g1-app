//
//  AppSettings.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import SwiftUI
import Combine

/// App settings model
class AppSettings: ObservableObject, Codable, Equatable {
    // Encoder/Decoder für @Published Properties
    private enum CodablePublishedWrapper<T> {
        case published(T)
    }
    
    private var cancellables = Set<AnyCancellable>()
    // Teleprompter settings
    @Published var teleprompterSpeed: Double = 1.0
    @Published var fontSizeMultiplier: Double = 1.0
    @Published var lineSpacing: Double = 1.0
    @Published var useMonospaceFont: Bool = false
    @Published var showCountdown: Bool = true
    @Published var countdownDuration: TimeInterval = 3.0
    
    // Appearance settings
    @Published var isDarkMode: Bool = false
    @Published var useSystemAppearance: Bool = true
    
    // Connection settings
    @Published var autoReconnect: Bool = true
    @Published var scanTimeout: Double = 10.0
    @Published var activeProfileId: UUID? = nil
    
    // Protocol settings
    @Published var useFraming: Bool = false
    @Published var maxPacketSize: Int = 20
    @Published var writeWithResponse: Bool = false
    @Published var encoding: String = "utf8"
    
    // Feature settings
    @Published var enableVoiceInput: Bool = true
    @Published var enableBackgroundMode: Bool = true
    @Published var enableWidgets: Bool = true
    @Published var enableLiveActivity: Bool = true
    @Published var useCloudSync: Bool = true
    
    // Fitness settings
    @Published var showFitnessMetricsOnGlasses: Bool = false
    @Published var autoSendWorkoutUpdates: Bool = false
    @Published var fitnessMetricsUpdateInterval: TimeInterval = 30.0 // seconds
    @Published var selectedFitnessMetrics: [String] = ["heartRate", "steps", "calories"]
    
    // Diagnostic settings
    @Published var verboseLogging: Bool = false
    @Published var logRetentionDays: Int = 7
    
    // MARK: - Codable
    
    init() {
        setupPublishers()
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        teleprompterSpeed = try container.decode(Double.self, forKey: .teleprompterSpeed)
        fontSizeMultiplier = try container.decode(Double.self, forKey: .fontSizeMultiplier)
        lineSpacing = try container.decode(Double.self, forKey: .lineSpacing)
        useMonospaceFont = try container.decode(Bool.self, forKey: .useMonospaceFont)
        showCountdown = try container.decode(Bool.self, forKey: .showCountdown)
        countdownDuration = try container.decode(TimeInterval.self, forKey: .countdownDuration)
        isDarkMode = try container.decode(Bool.self, forKey: .isDarkMode)
        useSystemAppearance = try container.decode(Bool.self, forKey: .useSystemAppearance)
        autoReconnect = try container.decode(Bool.self, forKey: .autoReconnect)
        scanTimeout = try container.decode(Double.self, forKey: .scanTimeout)
        activeProfileId = try container.decodeIfPresent(UUID.self, forKey: .activeProfileId)
        useFraming = try container.decode(Bool.self, forKey: .useFraming)
        maxPacketSize = try container.decode(Int.self, forKey: .maxPacketSize)
        writeWithResponse = try container.decode(Bool.self, forKey: .writeWithResponse)
        encoding = try container.decode(String.self, forKey: .encoding)
        enableVoiceInput = try container.decode(Bool.self, forKey: .enableVoiceInput)
        enableBackgroundMode = try container.decode(Bool.self, forKey: .enableBackgroundMode)
        enableWidgets = try container.decode(Bool.self, forKey: .enableWidgets)
        enableLiveActivity = try container.decode(Bool.self, forKey: .enableLiveActivity)
        useCloudSync = try container.decode(Bool.self, forKey: .useCloudSync)
        showFitnessMetricsOnGlasses = try container.decode(Bool.self, forKey: .showFitnessMetricsOnGlasses)
        autoSendWorkoutUpdates = try container.decode(Bool.self, forKey: .autoSendWorkoutUpdates)
        fitnessMetricsUpdateInterval = try container.decode(TimeInterval.self, forKey: .fitnessMetricsUpdateInterval)
        selectedFitnessMetrics = try container.decode([String].self, forKey: .selectedFitnessMetrics)
        verboseLogging = try container.decode(Bool.self, forKey: .verboseLogging)
        logRetentionDays = try container.decode(Int.self, forKey: .logRetentionDays)
        
        // Setup publishers to save settings when changed
        setupPublishers()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(teleprompterSpeed, forKey: .teleprompterSpeed)
        try container.encode(fontSizeMultiplier, forKey: .fontSizeMultiplier)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(useMonospaceFont, forKey: .useMonospaceFont)
        try container.encode(showCountdown, forKey: .showCountdown)
        try container.encode(countdownDuration, forKey: .countdownDuration)
        try container.encode(isDarkMode, forKey: .isDarkMode)
        try container.encode(useSystemAppearance, forKey: .useSystemAppearance)
        try container.encode(autoReconnect, forKey: .autoReconnect)
        try container.encode(scanTimeout, forKey: .scanTimeout)
        try container.encodeIfPresent(activeProfileId, forKey: .activeProfileId)
        try container.encode(useFraming, forKey: .useFraming)
        try container.encode(maxPacketSize, forKey: .maxPacketSize)
        try container.encode(writeWithResponse, forKey: .writeWithResponse)
        try container.encode(encoding, forKey: .encoding)
        try container.encode(enableVoiceInput, forKey: .enableVoiceInput)
        try container.encode(enableBackgroundMode, forKey: .enableBackgroundMode)
        try container.encode(enableWidgets, forKey: .enableWidgets)
        try container.encode(enableLiveActivity, forKey: .enableLiveActivity)
        try container.encode(useCloudSync, forKey: .useCloudSync)
        try container.encode(showFitnessMetricsOnGlasses, forKey: .showFitnessMetricsOnGlasses)
        try container.encode(autoSendWorkoutUpdates, forKey: .autoSendWorkoutUpdates)
        try container.encode(fitnessMetricsUpdateInterval, forKey: .fitnessMetricsUpdateInterval)
        try container.encode(selectedFitnessMetrics, forKey: .selectedFitnessMetrics)
        try container.encode(verboseLogging, forKey: .verboseLogging)
        try container.encode(logRetentionDays, forKey: .logRetentionDays)
    }
    
    private func setupPublishers() {
        // Auto-save settings when any property changes
        let publisher = Publishers.MergeMany(
            $teleprompterSpeed.dropFirst(),
            $fontSizeMultiplier.dropFirst(),
            $lineSpacing.dropFirst(),
            $useMonospaceFont.dropFirst(),
            $showCountdown.dropFirst(),
            $countdownDuration.dropFirst(),
            $isDarkMode.dropFirst(),
            $useSystemAppearance.dropFirst(),
            $autoReconnect.dropFirst(),
            $scanTimeout.dropFirst(),
            $useFraming.dropFirst(),
            $maxPacketSize.dropFirst(),
            $writeWithResponse.dropFirst(),
            $encoding.dropFirst(),
            $enableVoiceInput.dropFirst(),
            $enableBackgroundMode.dropFirst(),
            $enableWidgets.dropFirst(),
            $enableLiveActivity.dropFirst(),
            $useCloudSync.dropFirst(),
            $showFitnessMetricsOnGlasses.dropFirst(),
            $autoSendWorkoutUpdates.dropFirst(),
            $fitnessMetricsUpdateInterval.dropFirst(),
            $verboseLogging.dropFirst(),
            $logRetentionDays.dropFirst()
        )
        
        publisher
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }
    
    enum CodingKeys: String, CodingKey {
        case teleprompterSpeed, fontSizeMultiplier, lineSpacing, useMonospaceFont
        case showCountdown, countdownDuration, isDarkMode, useSystemAppearance, autoReconnect, scanTimeout
        case activeProfileId, useFraming, maxPacketSize, writeWithResponse, encoding
        case enableVoiceInput, enableBackgroundMode, enableWidgets
        case enableLiveActivity, useCloudSync, verboseLogging, logRetentionDays
        case showFitnessMetricsOnGlasses, autoSendWorkoutUpdates, fitnessMetricsUpdateInterval
        case selectedFitnessMetrics
    }
    
    // MARK: - Equatable
    
    static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        return lhs.teleprompterSpeed == rhs.teleprompterSpeed &&
               lhs.fontSizeMultiplier == rhs.fontSizeMultiplier &&
               lhs.lineSpacing == rhs.lineSpacing &&
               lhs.useMonospaceFont == rhs.useMonospaceFont &&
               lhs.showCountdown == rhs.showCountdown &&
               lhs.countdownDuration == rhs.countdownDuration &&
               lhs.isDarkMode == rhs.isDarkMode &&
               lhs.useSystemAppearance == rhs.useSystemAppearance &&
               lhs.autoReconnect == rhs.autoReconnect &&
               lhs.scanTimeout == rhs.scanTimeout &&
               lhs.activeProfileId == rhs.activeProfileId &&
               lhs.useFraming == rhs.useFraming &&
               lhs.maxPacketSize == rhs.maxPacketSize &&
               lhs.writeWithResponse == rhs.writeWithResponse &&
               lhs.encoding == rhs.encoding &&
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