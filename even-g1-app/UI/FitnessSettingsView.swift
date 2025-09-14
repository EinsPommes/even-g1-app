//
//  FitnessSettingsView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI

struct FitnessSettingsView: View {
    @EnvironmentObject private var fitnessManager: FitnessManager
    @EnvironmentObject private var appState: AppState
    
    @State private var settings: AppSettings
    @State private var selectedMetrics: [String]
    
    init() {
        _settings = State(initialValue: AppSettings.load())
        _selectedMetrics = State(initialValue: AppSettings.load().selectedFitnessMetrics)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Glasses Integration")) {
                Toggle("Show Fitness Metrics on Glasses", isOn: $settings.showFitnessMetricsOnGlasses)
                
                if settings.showFitnessMetricsOnGlasses {
                    Toggle("Auto-send Workout Updates", isOn: $settings.autoSendWorkoutUpdates)
                    
                    HStack {
                        Text("Update Interval")
                        Spacer()
                        Text("\(Int(settings.fitnessMetricsUpdateInterval)) seconds")
                    }
                    
                    Slider(value: $settings.fitnessMetricsUpdateInterval, in: 5...60, step: 5)
                }
            }
            
            Section(header: Text("Displayed Metrics")) {
                ForEach(availableMetrics, id: \.self) { metric in
                    Button(action: {
                        toggleMetric(metric)
                    }) {
                        HStack {
                            Image(systemName: iconForMetric(metric))
                                .foregroundColor(.blue)
                            
                            Text(displayNameForMetric(metric))
                            
                            Spacer()
                            
                            if selectedMetrics.contains(metric) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            
            Section(header: Text("Health Permissions")) {
                if !fitnessManager.isHealthKitAvailable {
                    Text("HealthKit is not available on this device")
                        .foregroundColor(.secondary)
                } else if !fitnessManager.isHealthKitAuthorized {
                    Button(action: {
                        fitnessManager.requestHealthKitAuthorization()
                    }) {
                        Text("Request Health Access")
                    }
                } else {
                    Text("Health access granted")
                        .foregroundColor(.green)
                }
                
                NavigationLink(destination: Text("Health Privacy Policy")) {
                    Text("Privacy Policy")
                }
            }
        }
        .navigationTitle("Fitness Settings")
        .onChange(of: settings) { newSettings in
            // Save selected metrics
            newSettings.selectedFitnessMetrics = selectedMetrics
            
            // Save settings
            newSettings.save()
            appState.settings = newSettings
        }
    }
    
    private var availableMetrics: [String] {
        return ["heartRate", "steps", "calories", "distance", "pace", "duration"]
    }
    
    private func toggleMetric(_ metric: String) {
        if selectedMetrics.contains(metric) {
            selectedMetrics.removeAll { $0 == metric }
        } else {
            selectedMetrics.append(metric)
        }
        
        // Update settings
        settings.selectedFitnessMetrics = selectedMetrics
    }
    
    private func displayNameForMetric(_ metric: String) -> String {
        switch metric {
        case "heartRate": return "Heart Rate"
        case "steps": return "Steps"
        case "calories": return "Calories"
        case "distance": return "Distance"
        case "pace": return "Pace"
        case "duration": return "Duration"
        default: return metric.capitalized
        }
    }
    
    private func iconForMetric(_ metric: String) -> String {
        switch metric {
        case "heartRate": return "heart.fill"
        case "steps": return "figure.walk"
        case "calories": return "flame.fill"
        case "distance": return "map"
        case "pace": return "speedometer"
        case "duration": return "clock"
        default: return "questionmark.circle"
        }
    }
}

struct FitnessSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FitnessSettingsView()
                .environmentObject(FitnessManager())
                .environmentObject(AppState())
        }
    }
}
