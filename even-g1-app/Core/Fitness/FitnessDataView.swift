//
//  FitnessDataView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI

struct FitnessDataView: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bleManager: BLEManager
    
    @State private var selectedMetrics: [FitnessMetric] = [.heartRate, .steps, .calories, .distance]
    @State private var showDeviceSelector = false
    @State private var showWorkoutControls = false
    @State private var selectedWorkoutType: WorkoutType = .running
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Health authorization status
                    if !fitnessManager.isHealthKitAvailable {
                        HealthUnavailableView()
                    } else if !fitnessManager.isHealthKitAuthorized {
                        HealthUnauthorizedView()
                    } else {
                        // Current metrics display
                        MetricsGridView(selectedMetrics: selectedMetrics)
                        
                        // Workout controls
                        WorkoutControlsView()
                        
                        // Send to glasses button
                        SendToGlassesButton()
                    }
                    
                    // Connected devices
                    ConnectedDevicesView()
                }
                .padding()
            }
            .navigationTitle("Fitness")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDeviceSelector = true
                    }) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Toggle workout controls
                        showWorkoutControls.toggle()
                    }) {
                        Image(systemName: "figure.run")
                    }
                }
            }
            .sheet(isPresented: $showDeviceSelector) {
                FitnessDeviceSelectorView()
            }
            .sheet(isPresented: $showWorkoutControls) {
                WorkoutSetupView(selectedWorkoutType: $selectedWorkoutType)
            }
            .onAppear {
                if fitnessManager.isHealthKitAvailable && !fitnessManager.isHealthKitAuthorized {
                    fitnessManager.requestHealthKitAuthorization()
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct HealthUnavailableView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("HealthKit Not Available")
                .font(.headline)
            
            Text("This device does not support HealthKit. Some fitness features will be limited.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct HealthUnauthorizedView: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Health Access Required")
                .font(.headline)
            
            Text("Please authorize access to your health data to enable fitness tracking features.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                fitnessManager.requestHealthKitAuthorization()
            }) {
                Text("Authorize Access")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct MetricsGridView: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    let selectedMetrics: [FitnessMetric]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
            ForEach(selectedMetrics, id: \.self) { metric in
                MetricCardView(metric: metric)
            }
        }
    }
}

struct MetricCardView: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    let metric: FitnessMetric
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: metric.iconName)
                    .font(.system(size: 16))
                Text(metric.title)
                    .font(.headline)
                Spacer()
            }
            
            Text(metricValue)
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)
            
            if metric == .heartRate {
                // Heart rate zone indicator
                ZoneIndicatorView(zone: fitnessManager.heartRateZone(for: fitnessManager.heartRate))
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var metricValue: String {
        switch metric {
        case .heartRate:
            return "\(Int(fitnessManager.heartRate)) BPM"
        case .steps:
            return "\(fitnessManager.steps) steps"
        case .calories:
            return "\(Int(fitnessManager.calories)) kcal"
        case .distance:
            return String(format: "%.2f km", fitnessManager.distance)
        case .pace:
            return String(format: "%.2f min/km", fitnessManager.pace)
        case .duration:
            return fitnessManager.formatDuration(fitnessManager.workoutDuration)
        }
    }
}

struct ZoneIndicatorView: View {
    let zone: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Rectangle()
                    .fill(zoneColor(for: i))
                    .frame(height: 6)
                    .cornerRadius(3)
            }
        }
    }
    
    private func zoneColor(for index: Int) -> Color {
        if index <= zone {
            switch index {
            case 1: return .green
            case 2: return .blue
            case 3: return .yellow
            case 4: return .orange
            case 5: return .red
            default: return .gray
            }
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

struct WorkoutControlsView: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    
    var body: some View {
        VStack(spacing: 15) {
            if fitnessManager.workoutState == .notStarted || fitnessManager.workoutState == .completed {
                // No active workout
                HStack {
                    Image(systemName: "figure.\(fitnessManager.workoutType.rawValue.lowercased())")
                        .font(.system(size: 40))
                    
                    VStack(alignment: .leading) {
                        Text("No Active Workout")
                            .font(.headline)
                        Text("Start a workout to track your fitness metrics")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
            } else {
                // Active workout
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "figure.\(fitnessManager.workoutType.rawValue.lowercased())")
                            .font(.system(size: 30))
                        
                        VStack(alignment: .leading) {
                            Text("\(fitnessManager.workoutType.rawValue) Workout")
                                .font(.headline)
                            Text(fitnessManager.workoutState == .active ? "In Progress" : "Paused")
                                .font(.subheadline)
                                .foregroundColor(fitnessManager.workoutState == .active ? .green : .orange)
                        }
                        
                        Spacer()
                        
                        Text(fitnessManager.formatDuration(fitnessManager.workoutDuration))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                    }
                    
                    HStack(spacing: 20) {
                        if fitnessManager.workoutState == .active {
                            Button(action: {
                                fitnessManager.pauseWorkout()
                            }) {
                                Image(systemName: "pause.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                            }
                        } else {
                            Button(action: {
                                fitnessManager.resumeWorkout()
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button(action: {
                            fitnessManager.endWorkout()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

struct SendToGlassesButton: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    @EnvironmentObject private var bleManager: BLEManager
    @State private var isSending = false
    @State private var showingOptions = false
    @State private var selectedTemplate: FitnessTemplate = .heartRate
    
    var body: some View {
        VStack(spacing: 15) {
            Button(action: {
                showingOptions = true
            }) {
                HStack {
                    Image(systemName: "glasses")
                    Text("Send to G1 Glasses")
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
            .disabled(bleManager.connectedDevices.isEmpty)
            
            if showingOptions {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select data to send:")
                        .font(.headline)
                    
                    ForEach(FitnessTemplate.allCases, id: \.self) { template in
                        Button(action: {
                            selectedTemplate = template
                            sendDataToGlasses(template: template)
                            showingOptions = false
                        }) {
                            HStack {
                                Image(systemName: template.iconName)
                                Text(template.title)
                                Spacer()
                                Text(previewText(for: template))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    Button(action: {
                        showingOptions = false
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func previewText(for template: FitnessTemplate) -> String {
        switch template {
        case .heartRate:
            return "\(Int(fitnessManager.heartRate)) BPM"
        case .workoutSummary:
            return "\(fitnessManager.workoutType.rawValue) - \(fitnessManager.formatDuration(fitnessManager.workoutDuration))"
        case .currentPace:
            return String(format: "%.2f min/km", fitnessManager.pace)
        case .caloriesBurned:
            return "\(Int(fitnessManager.calories)) kcal"
        }
    }
    
    private func sendDataToGlasses(template: FitnessTemplate) {
        guard !bleManager.connectedDevices.isEmpty else { return }
        
        isSending = true
        
        // Prepare text based on template
        var text = ""
        
        switch template {
        case .heartRate:
            text = "HR: \(Int(fitnessManager.heartRate)) BPM (Zone \(fitnessManager.heartRateZone(for: fitnessManager.heartRate)))"
        case .workoutSummary:
            text = "\(fitnessManager.workoutType.rawValue) Workout\nTime: \(fitnessManager.formatDuration(fitnessManager.workoutDuration))\nHR: \(Int(fitnessManager.heartRate)) BPM\nCal: \(Int(fitnessManager.calories))"
        case .currentPace:
            text = "Current Pace: \(String(format: "%.2f min/km", fitnessManager.pace))"
        case .caloriesBurned:
            text = "Calories: \(Int(fitnessManager.calories)) kcal"
        }
        
        // Send to glasses
        Task {
            _ = await bleManager.broadcastText(text)
            
            await MainActor.run {
                isSending = false
            }
        }
    }
}

struct ConnectedDevicesView: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connected Fitness Devices")
                .font(.headline)
            
            if fitnessManager.connectedDevices.isEmpty {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    Text("No fitness devices connected")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            } else {
                ForEach(fitnessManager.connectedDevices) { device in
                    DeviceRow(device: device)
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: FitnessDevice
    @EnvironmentObject private var fitnessManager: FitnessManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                Text(device.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if device.isConnected {
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
                
                Button(action: {
                    fitnessManager.disconnectFromDevice(device)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            } else {
                Button(action: {
                    fitnessManager.connectToDevice(device)
                }) {
                    Text("Connect")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FitnessDeviceSelectorView: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Available Devices")) {
                    if fitnessManager.connectedDevices.isEmpty {
                        if isScanning {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Scanning for devices...")
                            }
                        } else {
                            Text("No devices found")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(fitnessManager.connectedDevices) { device in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .font(.headline)
                                    Text(device.type.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if device.isConnected {
                                    Button(action: {
                                        fitnessManager.disconnectFromDevice(device)
                                    }) {
                                        Text("Disconnect")
                                            .foregroundColor(.red)
                                    }
                                } else {
                                    Button(action: {
                                        fitnessManager.connectToDevice(device)
                                    }) {
                                        Text("Connect")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fitness Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isScanning = true
                        fitnessManager.startScanningForDevices()
                        
                        // Auto-disable scanning after 10 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            isScanning = false
                        }
                    }) {
                        if isScanning {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isScanning)
                }
            }
            .onAppear {
                if fitnessManager.connectedDevices.isEmpty {
                    isScanning = true
                    fitnessManager.startScanningForDevices()
                    
                    // Auto-disable scanning after 10 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        isScanning = false
                    }
                }
            }
        }
    }
}

struct WorkoutSetupView: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedWorkoutType: WorkoutType
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Workout Type")) {
                    Picker("Type", selection: $selectedWorkoutType) {
                        ForEach(WorkoutType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Button(action: {
                        fitnessManager.startWorkout(type: selectedWorkoutType)
                        dismiss()
                    }) {
                        Text("Start Workout")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                    .disabled(fitnessManager.workoutState == .active || fitnessManager.workoutState == .paused)
                }
            }
            .navigationTitle("New Workout")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum FitnessMetric: String, CaseIterable {
    case heartRate = "Heart Rate"
    case steps = "Steps"
    case calories = "Calories"
    case distance = "Distance"
    case pace = "Pace"
    case duration = "Duration"
    
    var title: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .steps: return "figure.walk"
        case .calories: return "flame.fill"
        case .distance: return "map"
        case .pace: return "speedometer"
        case .duration: return "clock"
        }
    }
}

enum FitnessTemplate: String, CaseIterable {
    case heartRate = "Heart Rate"
    case workoutSummary = "Workout Summary"
    case currentPace = "Current Pace"
    case caloriesBurned = "Calories Burned"
    
    var title: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .workoutSummary: return "list.bullet"
        case .currentPace: return "speedometer"
        case .caloriesBurned: return "flame.fill"
        }
    }
}

// MARK: - Preview

struct FitnessDataView_Previews: PreviewProvider {
    static var previews: some View {
        FitnessDataView()
            .environmentObject(FitnessManager())
            .environmentObject(AppState())
            .environmentObject(BLEManager())
    }
}
