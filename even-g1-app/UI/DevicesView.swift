//
//  DevicesView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI
import CoreBluetooth

struct DevicesView: View {
    @EnvironmentObject private var bleManager: BLEManager
    @EnvironmentObject private var appState: AppState
    
    @State private var isScanning = false
    @State private var showingDeviceDetail = false
    @State private var selectedDevice: CBPeripheral?
    @State private var selectedRole: DeviceRole = .unknown
    
    var body: some View {
        NavigationStack {
            List {
                // Connected devices
                Section(header: Text("Connected Devices")) {
                    if bleManager.connectedDevices.isEmpty {
                        Text("No connected devices")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(bleManager.connectedDevices) { device in
                            ConnectedDeviceRow(device: device)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        bleManager.disconnect(deviceId: device.id)
                                    } label: {
                                        Label("Disconnect", systemImage: "xmark.circle")
                                    }
                                }
                        }
                    }
                }
                
                // Discovered devices
                Section(header: Text("Available Devices")) {
                    if isScanning && bleManager.discoveredPeripherals.isEmpty {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Searching for devices...")
                        }
                    } else if !isScanning && bleManager.discoveredPeripherals.isEmpty {
                        Text("No devices found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            Button(action: {
                                selectedDevice = peripheral
                                showingDeviceDetail = true
                            }) {
                                DiscoveredDeviceRow(peripheral: peripheral)
                            }
                        }
                    }
                }
                
                // Known devices
                Section(header: Text("Known Devices")) {
                    if bleManager.knownDevices.isEmpty {
                        Text("No known devices")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(bleManager.knownDevices) { device in
                            KnownDeviceRow(device: device)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        // Remove known device
                                        if let index = bleManager.knownDevices.firstIndex(where: { $0.id == device.id }) {
                                            bleManager.knownDevices.remove(at: index)
                                        }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleScan) {
                        if isScanning {
                            Label("Stop", systemImage: "stop.circle")
                        } else {
                            Label("Scan", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                }
            }
            .refreshable {
                if !isScanning {
                    startScan()
                }
            }
            .sheet(isPresented: $showingDeviceDetail) {
                DeviceConnectionSheet(
                    peripheral: selectedDevice,
                    selectedRole: $selectedRole,
                    onConnect: { role in
                        if let peripheral = selectedDevice {
                            bleManager.connect(to: peripheral, as: role)
                        }
                        showingDeviceDetail = false
                    },
                    onCancel: {
                        showingDeviceDetail = false
                    }
                )
            }
            .onAppear {
                // Sync status
                isScanning = bleManager.isScanning
            }
        }
    }
    
    private func toggleScan() {
        if isScanning {
            stopScan()
        } else {
            startScan()
        }
    }
    
    private func startScan() {
        isScanning = true
        bleManager.startScan()
        
        // Stop scan after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + appState.settings.scanTimeout) {
            if self.isScanning {
                self.stopScan()
            }
        }
    }
    
    private func stopScan() {
        isScanning = false
        bleManager.stopScan()
    }
}

// MARK: - Connected Device Row

struct ConnectedDeviceRow: View {
    @ObservedObject var device: BLEDeviceStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.knownDevice.displayName)
                    .font(.headline)
                
                HStack {
                    Text(device.knownDevice.role.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(roleColor(for: device.knownDevice.role).opacity(0.2))
                        )
                        .foregroundColor(roleColor(for: device.knownDevice.role))
                    
                    Spacer()
                    
                    if let battery = device.batteryLevel {
                        Label("\(battery)%", systemImage: batteryIcon(for: battery))
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
            
            // RSSI indicator
            SignalStrengthIndicator(rssi: device.rssi)
                .frame(width: 24, height: 24)
        }
    }
    
    private func roleColor(for role: DeviceRole) -> Color {
        switch role {
        case .left:
            return .blue
        case .right:
            return .green
        case .unknown:
            return .gray
        }
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

// MARK: - Discovered Device Row

struct DiscoveredDeviceRow: View {
    let peripheral: CBPeripheral
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(peripheral.name ?? "Unknown Device")
                    .font(.headline)
                Text(peripheral.identifier.uuidString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "plus.circle")
                .foregroundColor(.accentColor)
        }
    }
}

// MARK: - Known Device Row

struct KnownDeviceRow: View {
    let device: KnownDevice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.displayName)
                    .font(.headline)
                
                HStack {
                    Text(device.role.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(roleColor(for: device.role).opacity(0.2))
                        )
                        .foregroundColor(roleColor(for: device.role))
                    
                    if let lastConnected = device.lastConnected {
                        Spacer()
                        Text("Last: \(formattedDate(lastConnected))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { device.autoReconnect },
                set: { _ in }
            ))
            .labelsHidden()
            .disabled(true)
        }
    }
    
    private func roleColor(for role: DeviceRole) -> Color {
        switch role {
        case .left:
            return .blue
        case .right:
            return .green
        case .unknown:
            return .gray
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Device Connection Sheet

struct DeviceConnectionSheet: View {
    let peripheral: CBPeripheral?
    @Binding var selectedRole: DeviceRole
    let onConnect: (DeviceRole) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Device")) {
                    Text(peripheral?.name ?? "Unknown Device")
                        .font(.headline)
                    Text(peripheral?.identifier.uuidString ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Role")) {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(DeviceRole.allCases) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button(action: {
                        onConnect(selectedRole)
                    }) {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.accentColor)
                }
            }
            .navigationTitle("Connect Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Signal Strength Indicator

struct SignalStrengthIndicator: View {
    let rssi: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                Rectangle()
                    .fill(signalColor(for: i))
                    .frame(width: 3, height: 8 + CGFloat(i) * 4)
            }
        }
    }
    
    private func signalColor(for bar: Int) -> Color {
        let strength = rssi
        
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
}

// MARK: - Preview

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView()
            .environmentObject(AppState())
            .environmentObject(BLEManager())
    }
}
