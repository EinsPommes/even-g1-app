//
//  SubtitlesView.swift
//  even-g1-app
//
//  Created by oxo.mika on 02/10/2025.
//

import SwiftUI

struct SubtitlesView: View {
    @StateObject private var subtitlesManager = SubtitlesManager()
    @State private var showingGlassesSelector = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Status and controls
                HStack {
                    // Status indicator
                    Circle()
                        .fill(subtitlesManager.isRecording ? Color.red : Color.gray)
                        .frame(width: 12, height: 12)
                    
                    Text(subtitlesManager.isRecording ? "Recording" : "Ready")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Record button
                    Button(action: {
                        subtitlesManager.startRecording()
                    }) {
                        Image(systemName: subtitlesManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(subtitlesManager.isRecording ? .red : .blue)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Connected glasses info
                if let selectedId = subtitlesManager.selectedGlassesId,
                   let glasses = subtitlesManager.getConnectedGlasses().first(where: { $0.id == selectedId }) {
                    HStack {
                        Image(systemName: "eyeglasses")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(glasses.name)
                                .font(.headline)
                            
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        // Battery indicator
                        HStack(spacing: 2) {
                            Image(systemName: "battery.\(glasses.batteryPercentage)")
                                .foregroundColor(batteryColor(percentage: glasses.batteryPercentage))
                            
                            Text("\(glasses.batteryPercentage)%")
                                .font(.caption)
                        }
                        
                        Button(action: {
                            showingGlassesSelector = true
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.body)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                } else {
                    Button(action: {
                        showingGlassesSelector = true
                    }) {
                        HStack {
                            Image(systemName: "eyeglasses")
                            Text("Select G1 Glasses")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Current subtitle display
                VStack {
                    Text("Current Subtitle")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitlesManager.lastSubtitle.isEmpty ? "No subtitles yet" : subtitlesManager.lastSubtitle)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .animation(.easeInOut, value: subtitlesManager.lastSubtitle)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Full transcript
                VStack {
                    HStack {
                        Text("Full Transcript")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            subtitlesManager.transcribedText = ""
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    
                    ScrollView {
                        Text(subtitlesManager.transcribedText.isEmpty ? "Start recording to see transcript" : subtitlesManager.transcribedText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                Spacer()
                
                // Error display
                if let error = subtitlesManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemRed).opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("Subtitles")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingGlassesSelector) {
                GlassesSelectorView(subtitlesManager: subtitlesManager)
            }
            .sheet(isPresented: $showingSettings) {
                SubtitlesSettingsView(subtitlesManager: subtitlesManager)
            }
            .onAppear {
                subtitlesManager.checkPermissions()
            }
        }
    }
    
    private func batteryColor(percentage: Int) -> Color {
        if percentage <= 20 {
            return .red
        } else if percentage <= 40 {
            return .orange
        } else {
            return .green
        }
    }
}

struct GlassesSelectorView: View {
    @ObservedObject var subtitlesManager: SubtitlesManager
    @Environment(\.dismiss) private var dismiss
    @State private var glasses: [G1Glasses] = []
    @State private var isScanning = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if glasses.isEmpty {
                    VStack {
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("No G1 Glasses Found")
                            .font(.headline)
                        
                        Text("Tap Scan to look for glasses")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(glasses, id: \.id) { device in
                        Button(action: {
                            selectGlasses(device)
                        }) {
                            HStack {
                                Image(systemName: "eyeglasses")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .font(.headline)
                                    
                                    Text(connectionStateText(device.connectionState))
                                        .font(.caption)
                                        .foregroundColor(connectionStateColor(device.connectionState))
                                }
                                
                                Spacer()
                                
                                if device.id == subtitlesManager.selectedGlassesId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select G1 Glasses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        scanForGlasses()
                    }) {
                        if isScanning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Scan")
                        }
                    }
                }
            }
            .onAppear {
                refreshGlasses()
            }
        }
    }
    
    private func scanForGlasses() {
        isScanning = true
        subtitlesManager.scanForGlasses()
        
        // Schedule a refresh after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            refreshGlasses()
            isScanning = false
        }
    }
    
    private func refreshGlasses() {
        glasses = subtitlesManager.getConnectedGlasses()
    }
    
    private func selectGlasses(_ device: G1Glasses) {
        if device.connectionState == .connected {
            subtitlesManager.selectedGlassesId = device.id
            dismiss()
        } else {
            // Try to connect first
            Task {
                let success = await subtitlesManager.connectToGlasses(id: device.id)
                if success {
                    await MainActor.run {
                        subtitlesManager.selectedGlassesId = device.id
                        dismiss()
                    }
                } else {
                    // Show error or retry
                    print("Failed to connect")
                }
            }
        }
    }
    
    private func connectionStateText(_ state: G1ConnectionState) -> String {
        switch state {
        case .uninitialized:
            return "Initializing"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting"
        case .error:
            return "Error"
        }
    }
    
    private func connectionStateColor(_ state: G1ConnectionState) -> Color {
        switch state {
        case .connected:
            return .green
        case .connecting, .disconnecting:
            return .orange
        case .error:
            return .red
        default:
            return .gray
        }
    }
}

struct SubtitlesSettingsView: View {
    @ObservedObject var subtitlesManager: SubtitlesManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Glasses")) {
                    Toggle("Auto-send to glasses", isOn: $subtitlesManager.autoSendToGlasses)
                }
                
                Section(header: Text("Subtitle Display")) {
                    Stepper("Duration: \(subtitlesManager.subtitleDuration) ms", 
                           value: $subtitlesManager.subtitleDuration,
                           in: 1000...10000,
                           step: 500)
                    
                    Stepper("Max Length: \(subtitlesManager.maxSubtitleLength) chars", 
                           value: $subtitlesManager.maxSubtitleLength,
                           in: 20...60,
                           step: 5)
                }
                
                Section(header: Text("Permissions")) {
                    HStack {
                        Text("Microphone")
                        Spacer()
                        Text(authorizationStatusText(subtitlesManager.authorizationStatus))
                            .foregroundColor(authorizationStatusColor(subtitlesManager.authorizationStatus))
                    }
                    
                    Button("Check Permissions") {
                        subtitlesManager.checkPermissions()
                    }
                }
            }
            .navigationTitle("Subtitles Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func authorizationStatusText(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func authorizationStatusColor(_ status: SFSpeechRecognizerAuthorizationStatus) -> Color {
        switch status {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
}

struct SubtitlesView_Previews: PreviewProvider {
    static var previews: some View {
        SubtitlesView()
    }
}
