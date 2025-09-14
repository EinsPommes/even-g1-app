//
//  MainCoordinatorView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI

struct MainCoordinatorView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bleManager: BLEManager
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label(MainTab.home.rawValue, systemImage: MainTab.home.iconName)
                }
                .tag(MainTab.home)
            
            TeleprompterView()
                .tabItem {
                    Label(MainTab.teleprompter.rawValue, systemImage: MainTab.teleprompter.iconName)
                }
                .tag(MainTab.teleprompter)
            
            DevicesView()
                .tabItem {
                    Label(MainTab.devices.rawValue, systemImage: MainTab.devices.iconName)
                }
                .tag(MainTab.devices)
            
            TemplatesView()
                .tabItem {
                    Label(MainTab.templates.rawValue, systemImage: MainTab.templates.iconName)
                }
                .tag(MainTab.templates)
                
            FitnessDataView()
                .tabItem {
                    Label(MainTab.fitness.rawValue, systemImage: MainTab.fitness.iconName)
                }
                .tag(MainTab.fitness)
            
            SettingsView()
                .tabItem {
                    Label(MainTab.settings.rawValue, systemImage: MainTab.settings.iconName)
                }
                .tag(MainTab.settings)
        }
        .onAppear {
            setupAppearance()
        }
        .accentColor(.accentColor)
    }
    
    private func setupAppearance() {
        // Set tab bar appearance
        UITabBar.appearance().backgroundColor = UIColor.systemBackground
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bleManager: BLEManager
    
    @State private var text = ""
    @State private var isSending = false
    @State private var lastSendResult: [UUID: Result<Void, Error>]?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quick send section
                    VStack(alignment: .leading) {
                        Text("Quick Send")
                            .font(.headline)
                        
                        TextEditor(text: $text)
                            .frame(minHeight: 100)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        
                        Button(action: sendText) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Send")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(text.isEmpty || bleManager.connectedDevices.isEmpty || isSending)
                    }
                    
                    // Connected devices
                    VStack(alignment: .leading) {
                        Text("Connected Devices")
                            .font(.headline)
                        
                        if bleManager.connectedDevices.isEmpty {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                Text("No devices connected")
                                    .foregroundColor(.secondary)
                                Spacer()
                                NavigationLink(destination: DevicesView()) {
                                    Text("Connect")
                                        .font(.subheadline)
                                }
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            ForEach(bleManager.connectedDevices) { device in
                                DeviceStatusRow(device: device)
                            }
                        }
                    }
                    
                    // Recent templates
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Recent Templates")
                                .font(.headline)
                            Spacer()
                            NavigationLink(destination: TemplatesView()) {
                                Text("View All")
                                    .font(.subheadline)
                            }
                        }
                        
                        if appState.recentTemplates.isEmpty {
                            Text("No recent templates")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            ForEach(appState.recentTemplates) { template in
                                Button(action: {
                                    text = template.body
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(template.title)
                                            .font(.headline)
                                        Text(template.body.prefix(50))
                                            .font(.subheadline)
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Start teleprompter
                    Button(action: startTeleprompter) {
                        HStack {
                            Image(systemName: "text.viewfinder")
                            Text("Start Teleprompter")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(text.isEmpty)
                }
                .padding()
            }
            .navigationTitle("G1 OpenTeleprompter")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        appState.selectedTab = .devices
                    }) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                }
            }
        }
    }
    
    private func sendText() {
        guard !text.isEmpty, !bleManager.connectedDevices.isEmpty else { return }
        
        isSending = true
        
        Task {
            let results = await bleManager.broadcastText(text)
            
            await MainActor.run {
                lastSendResult = results
                isSending = false
            }
        }
    }
    
    private func startTeleprompter() {
        guard !text.isEmpty else { return }
        
        // Set text for teleprompter
        appState.teleprompterText = text
        
        // Switch to teleprompter view
        appState.selectedTab = .teleprompter
    }
}

// MARK: - Device Status Row

struct DeviceStatusRow: View {
    @ObservedObject var device: BLEDeviceStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.knownDevice.displayName)
                    .font(.headline)
                
                HStack {
                    Text(device.knownDevice.role.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let battery = device.batteryLevel {
                        Spacer()
                        Label("\(battery)%", systemImage: batteryIcon(for: battery))
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
            
            // RSSI indicator
            HStack(spacing: 2) {
                ForEach(0..<4) { i in
                    Rectangle()
                        .fill(signalColor(for: i))
                        .frame(width: 3, height: 8 + CGFloat(i) * 4)
                }
            }
            
            // Status indicator
            Circle()
                .fill(device.isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func signalColor(for bar: Int) -> Color {
        let strength = device.rssi
        
        if strength == 0 {
            return Color.secondary.opacity(0.3)
        }
        
        // RSSI values: -30 (very good) to -100 (very weak)
        let threshold: Int
        switch bar {
        case 0: threshold = -90 // First bar: -90 dBm or better
        case 1: threshold = -80 // Second bar: -80 dBm or better
        case 2: threshold = -70 // Third bar: -70 dBm or better
        case 3: threshold = -60 // Fourth bar: -60 dBm or better
        default: threshold = -100
        }
        
        return strength >= threshold ? Color.blue : Color.secondary.opacity(0.3)
    }
    
    private func batteryIcon(for level: Int) -> String {
        if level <= 5 {
            return "battery.0"
        } else if level <= 20 {
            return "battery.25"
        } else if level <= 40 {
            return "battery.50"
        } else if level <= 80 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
}

// MARK: - Placeholder Views
// These have been moved to separate files

// MARK: - Preview

struct MainCoordinatorView_Previews: PreviewProvider {
    static var previews: some View {
        MainCoordinatorView()
            .environmentObject(AppState())
            .environmentObject(BLEManager())
    }
}
