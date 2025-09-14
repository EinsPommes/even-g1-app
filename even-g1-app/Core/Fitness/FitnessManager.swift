//
//  FitnessManager.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import HealthKit
import Combine
import os.log

/// Manages fitness data 
class FitnessManager: ObservableObject {
    private let logger = Logger(subsystem: "com.evenreality.g1-teleprompter", category: "FitnessManager")
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    // Published fitness metrics
    @Published var heartRate: Double = 0
    @Published var steps: Int = 0
    @Published var calories: Double = 0
    @Published var distance: Double = 0
    @Published var pace: Double = 0
    @Published var workoutState: WorkoutState = .notStarted
    @Published var workoutType: WorkoutType = .running
    @Published var workoutDuration: TimeInterval = 0
    @Published var isHealthKitAvailable: Bool = false
    @Published var isHealthKitAuthorized: Bool = false
    @Published var connectedDevices: [FitnessDevice] = []
    
    // Workout timer
    private var workoutStartTime: Date?
    private var workoutTimer: Timer?
    
    init() {
        checkHealthKitAvailability()
    }
    
    // MARK: - HealthKit Authorization
    
    /// Checks if HealthKit is available on this device
    private func checkHealthKitAvailability() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
        logger.info("HealthKit availability: \(self.isHealthKitAvailable)")
    }
    
    /// Requests authorization for HealthKit data types
    func requestHealthKitAuthorization() {
        guard isHealthKitAvailable else {
            logger.warning("HealthKit is not available on this device")
            return
        }
        
        // Define the health data types to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isHealthKitAuthorized = success
                if let error = error {
                    self?.logger.error("HealthKit authorization error: \(error.localizedDescription)")
                } else {
                    self?.logger.info("HealthKit authorization: \(success)")
                    if success {
                        self?.startObservingHealthData()
                    }
                }
            }
        }
    }
    
    // MARK: - HealthKit Data Observation
    
    /// Starts observing health data updates
    private func startObservingHealthData() {
        startHeartRateQuery()
        startStepCountQuery()
        startCaloriesQuery()
        startDistanceQuery()
    }
    
    /// Sets up a streaming query for heart rate updates
    private func startHeartRateQuery() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                self?.logger.error("Heart rate observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            self?.fetchLatestHeartRate()
            completionHandler()
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error = error {
                self.logger.error("Failed to enable heart rate background delivery: \(error.localizedDescription)")
            }
        }
    }
    
    /// Fetches the latest heart rate reading
    private func fetchLatestHeartRate() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-60), end: nil, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] query, samples, error in
            guard let samples = samples as? [HKQuantitySample], let sample = samples.first else {
                return
            }
            
            DispatchQueue.main.async {
                let heartRateValue = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                self?.heartRate = heartRateValue
                self?.logger.debug("Updated heart rate: \(heartRateValue) BPM")
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Sets up a streaming query for step count updates
    private func startStepCountQuery() {
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        
        // Similar implementation as heart rate query but for steps
        // For brevity, implementation details are omitted
        // In a real implementation, this would query step count for today
    }
    
    /// Sets up a streaming query for calories burned updates
    private func startCaloriesQuery() {
        guard let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        // Similar implementation as heart rate query but for calories
        // For brevity, implementation details are omitted
    }
    
    /// Sets up a streaming query for distance updates
    private func startDistanceQuery() {
        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        
        // Similar implementation as heart rate query but for distance
        // For brevity, implementation details are omitted
    }
    
    // MARK: - External Fitness Devices
    
    /// Starts scanning for external fitness devices
    func startScanningForDevices() {
        // In a real implementation, this would use CoreBluetooth to scan for fitness devices
        // For this implementation, we'll simulate finding devices
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let simulatedDevices = [
                FitnessDevice(id: UUID(), name: "Garmin HRM Pro", type: .heartRateMonitor, isConnected: false),
                FitnessDevice(id: UUID(), name: "Polar H10", type: .heartRateMonitor, isConnected: false),
                FitnessDevice(id: UUID(), name: "Wahoo TICKR", type: .heartRateMonitor, isConnected: false),
                FitnessDevice(id: UUID(), name: "Stryd Power Meter", type: .footpod, isConnected: false)
            ]
            
            self.connectedDevices = simulatedDevices
            self.logger.info("Found \(simulatedDevices.count) fitness devices")
        }
    }
    
    /// Connects to a fitness device
    func connectToDevice(_ device: FitnessDevice) {
        // In a real implementation, this would establish a Bluetooth connection
        // For this implementation, we'll simulate connecting
        
        logger.info("Connecting to device: \(device.name)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let index = self.connectedDevices.firstIndex(where: { $0.id == device.id }) {
                self.connectedDevices[index].isConnected = true
                self.logger.info("Connected to device: \(device.name)")
                
                // Simulate data from device
                if device.type == .heartRateMonitor {
                    self.startSimulatedHeartRateUpdates()
                }
            }
        }
    }
    
    /// Disconnects from a fitness device
    func disconnectFromDevice(_ device: FitnessDevice) {
        logger.info("Disconnecting from device: \(device.name)")
        
        if let index = connectedDevices.firstIndex(where: { $0.id == device.id }) {
            connectedDevices[index].isConnected = false
            logger.info("Disconnected from device: \(device.name)")
        }
    }
    
    // MARK: - Workout Management
    
    /// Starts a workout session
    func startWorkout(type: WorkoutType) {
        guard workoutState != .active else { return }
        
        workoutType = type
        workoutState = .active
        workoutStartTime = Date()
        workoutDuration = 0
        
        // Start workout timer
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.workoutStartTime else { return }
            self.workoutDuration = Date().timeIntervalSince(startTime)
        }
        
        logger.info("Started \(type.rawValue) workout")
    }
    
    /// Pauses the current workout
    func pauseWorkout() {
        guard workoutState == .active else { return }
        
        workoutState = .paused
        workoutTimer?.invalidate()
        
        logger.info("Paused workout")
    }
    
    /// Resumes the paused workout
    func resumeWorkout() {
        guard workoutState == .paused else { return }
        
        workoutState = .active
        
        // Adjust start time to account for pause duration
        if let startTime = workoutStartTime {
            workoutStartTime = Date().addingTimeInterval(-workoutDuration)
        }
        
        // Restart timer
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.workoutStartTime else { return }
            self.workoutDuration = Date().timeIntervalSince(startTime)
        }
        
        logger.info("Resumed workout")
    }
    
    /// Ends the current workout
    func endWorkout() {
        guard workoutState == .active || workoutState == .paused else { return }
        
        workoutState = .completed
        workoutTimer?.invalidate()
        
        logger.info("Ended workout. Duration: \(formatDuration(workoutDuration))")
    }
    
    // MARK: - Data Formatting
    
    /// Formats a duration as a string (HH:MM:SS)
    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Formats heart rate as a string with zone indication
    func formattedHeartRate() -> String {
        let zone = heartRateZone(for: heartRate)
        return "\(Int(heartRate)) BPM (Zone \(zone))"
    }
    
    /// Determines heart rate zone (1-5) based on heart rate value
    func heartRateZone(for heartRate: Double) -> Int {
        // Simple zone calculation (would be more sophisticated in a real app)
        if heartRate < 110 {
            return 1
        } else if heartRate < 130 {
            return 2
        } else if heartRate < 150 {
            return 3
        } else if heartRate < 170 {
            return 4
        } else {
            return 5
        }
    }
    
    // MARK: - Simulation Methods
    
    /// Simulates heart rate updates for testing
    private func startSimulatedHeartRateUpdates() {
        Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Generate realistic heart rate based on workout state
                var baseHeartRate: Double = 70
                
                switch self.workoutState {
                case .active:
                    switch self.workoutType {
                    case .running:
                        baseHeartRate = 150
                    case .cycling:
                        baseHeartRate = 140
                    case .walking:
                        baseHeartRate = 110
                    case .hiit:
                        baseHeartRate = 160
                    }
                case .paused:
                    baseHeartRate = 100
                default:
                    baseHeartRate = 70
                }
                
                // Add some variation
                let variation = Double.random(in: -10...10)
                self.heartRate = max(50, min(200, baseHeartRate + variation))
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

/// Represents a fitness device that can be connected to
struct FitnessDevice: Identifiable {
    let id: UUID
    let name: String
    let type: FitnessDeviceType
    var isConnected: Bool
    var batteryLevel: Int?
    var signalStrength: Int?
}

/// Types of fitness devices
enum FitnessDeviceType: String {
    case heartRateMonitor = "Heart Rate Monitor"
    case footpod = "Foot Pod"
    case powerMeter = "Power Meter"
    case smartWatch = "Smart Watch"
}

/// Current state of a workout
enum WorkoutState {
    case notStarted
    case active
    case paused
    case completed
}

/// Types of workouts
enum WorkoutType: String, CaseIterable, Identifiable {
    case running = "Running"
    case cycling = "Cycling"
    case walking = "Walking"
    case hiit = "HIIT"
    
    var id: String { self.rawValue }
}
