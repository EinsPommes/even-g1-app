//
//  SettingsView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var bleManager: BLEManager
    @EnvironmentObject var settings: AppSettings
    
    @State private var needsRefresh = false
    @State private var showingAddProfileSheet = false
    @State private var showingEditProfileSheet = false
    @State private var selectedProfile: ProtocolProfile?
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Bluetooth Status
                Section(header: Text("Bluetooth Status")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(bleStatusText)
                            .foregroundColor(bleStatusColor)
                    }
                    
                    if let error = bleManager.lastError {
                        HStack {
                            Text("Last error:")
                            Spacer()
                            Text(error.localizedDescription)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    HStack {
                        Text("Scanning")
                        Spacer()
                        Text(bleManager.isScanning ? "Active" : "Inactive")
                            .foregroundColor(bleManager.isScanning ? .green : .secondary)
                    }
                    
                    Button(action: {
                        if bleManager.isScanning {
                            bleManager.stopScan()
                        } else {
                            bleManager.startScan()
                        }
                    }) {
                        Text(bleManager.isScanning ? "Stop Scan" : "Start Scan")
                    }
                }
                
                // MARK: - Connected Devices
                if !bleManager.connectedDevices.isEmpty {
                    Section(header: Text("Connected Devices")) {
                        ForEach(bleManager.connectedDevices) { device in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                        .font(.headline)
                                    
                                    if device.isConnecting {
                                        Text("Connecting...")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else if device.isConnected {
                                        Text("Connected")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("Disconnected")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                Spacer()
                                
                                if let batteryLevel = device.batteryLevel {
                                    HStack {
                                        Image(systemName: batteryIconName(for: batteryLevel))
                                            .foregroundColor(batteryColor(for: batteryLevel))
                                        Text("\(batteryLevel)%")
                                    }
                                }
                                
                                Button(action: {
                                    bleManager.disconnect(deviceId: device.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                // MARK: - Known Devices
                Section(header: Text("Known Devices")) {
                    ForEach(bleManager.knownDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.displayName)
                                    .font(.headline)
                                Text(device.role.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("Auto", isOn: Binding(
                                get: { bleManager.knownDevices.first(where: { $0.id == device.id })?.autoReconnect ?? false },
                                set: { newValue in
                                    if let index = bleManager.knownDevices.firstIndex(where: { $0.id == device.id }) {
                                        bleManager.knownDevices[index].autoReconnect = newValue
                                        // Save the updated settings
                                        if let data = try? JSONEncoder().encode(bleManager.knownDevices) {
                                            UserDefaults.standard.set(data, forKey: "KnownDevices")
                                        }
                                    }
                                }
                            ))
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                bleManager.deleteKnownDevice(withId: device.identifier)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    
                    if bleManager.knownDevices.isEmpty {
                        Text("No known devices")
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - Scan Settings
                Section(header: Text("Scan Settings")) {
                    HStack {
                        Text("Scan Timeout")
                        Spacer()
                        Text("\(Int(settings.scanTimeout)) seconds")
                    }
                    
                    Slider(
                        value: Binding(
                            get: { settings.scanTimeout },
                            set: {
                                settings.scanTimeout = $0
                                needsRefresh.toggle() // Force UI update
                            }
                        ),
                        in: 5...30,
                        step: 1
                    )
                }
                
                // MARK: - Protocol Settings
                Section(header: Text("Protocol Settings")) {
                    if let activeProfile = bleManager.activeProfile {
                        HStack {
                            Text("Active Profile")
                            Spacer()
                            Text(activeProfile.name)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Text("No active profile")
                            .foregroundColor(.red)
                    }
                    
                    ForEach(bleManager.availableProfiles) { profile in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(.headline)
                                Text("Service: \(profile.serviceUUID)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if bleManager.activeProfile?.id == profile.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            bleManager.activateProfile(profile.id)
                            needsRefresh.toggle()
                        }
                        .swipeActions {
                            Button {
                                selectedProfile = profile
                                showingEditProfileSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    
                    Button(action: {
                        showingAddProfileSheet = true
                    }) {
                        Label("Add Profile", systemImage: "plus")
                    }
                }
                
                // MARK: - Teleprompter Settings
                Section(header: Text("Teleprompter Settings")) {
                    HStack {
                        Text("Speed")
                        Spacer()
                        Text(String(format: "%.1f", settings.teleprompterSpeed))
                    }
                    
                    Slider(
                        value: Binding(
                            get: { settings.teleprompterSpeed },
                            set: {
                                settings.teleprompterSpeed = $0
                                needsRefresh.toggle() // Force UI update
                            }
                        ),
                        in: 0.5...3.0,
                        step: 0.1
                    )
                    
                    HStack {
                        Text("Line Spacing")
                        Spacer()
                        Text(String(format: "%.1f", settings.lineSpacing))
                    }
                    
                    Slider(
                        value: Binding(
                            get: { settings.lineSpacing },
                            set: {
                                settings.lineSpacing = $0
                                needsRefresh.toggle() // Force UI update
                            }
                        ),
                        in: 1.0...2.0,
                        step: 0.1
                    )
                    
                    Toggle("Monospace Font", isOn: Binding(
                        get: { settings.useMonospaceFont },
                        set: {
                            settings.useMonospaceFont = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    Toggle("Show Countdown", isOn: Binding(
                        get: { settings.showCountdown },
                        set: {
                            settings.showCountdown = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    if settings.showCountdown {
                        HStack {
                            Text("Countdown Duration")
                            Spacer()
                            Text("\(Int(settings.countdownDuration)) seconds")
                        }
                        
                        Slider(
                            value: Binding(
                                get: { settings.countdownDuration },
                                set: {
                                    settings.countdownDuration = $0
                                    needsRefresh.toggle() // Force UI update
                                }
                            ),
                            in: 1...10,
                            step: 1
                        )
                    }
                }
                
                // MARK: - Framing Settings
                Section(header: Text("Framing")) {
                    Toggle("Use Framing", isOn: Binding(
                        get: { settings.useFraming },
                        set: {
                            settings.useFraming = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    if settings.useFraming {
                        HStack {
                            Text("Max Packet Size")
                            Spacer()
                            Text("\(settings.maxPacketSize) bytes")
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(settings.maxPacketSize) },
                                set: {
                                    settings.maxPacketSize = Int($0)
                                    needsRefresh.toggle() // Force UI update
                                }
                            ),
                            in: 10...100,
                            step: 1
                        )
                    }
                }
                
                // MARK: - Write Mode
                Section(header: Text("Write Mode")) {
                    Picker("Write Mode", selection: Binding(
                        get: { settings.writeWithResponse },
                        set: {
                            settings.writeWithResponse = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    )) {
                        Text("With Response").tag(true)
                        Text("Without Response").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                
                // MARK: - Encoding
                Section(header: Text("Encoding")) {
                    Picker("Encoding", selection: Binding(
                        get: { settings.encoding },
                        set: {
                            settings.encoding = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    )) {
                        Text("UTF-8").tag("utf8")
                        Text("Hex").tag("hex")
                    }
                    .pickerStyle(.segmented)
                }
                
                // MARK: - Appearance
                Section(header: Text("Appearance")) {
                    // Use System Setting toggle
                    Toggle("Use System Appearance", isOn: Binding(
                        get: { settings.useSystemAppearance },
                        set: {
                            settings.useSystemAppearance = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    // Only show the picker if not using system appearance
                    if !settings.useSystemAppearance {
                        Picker("Theme", selection: Binding(
                            get: { settings.isDarkMode },
                            set: {
                                settings.isDarkMode = $0
                                needsRefresh.toggle() // Force UI update
                            }
                        )) {
                            Text("Light").tag(false)
                            Text("Dark").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                // MARK: - Fitness Settings
                Section(header: Text("Fitness")) {
                    NavigationLink(destination: FitnessSettingsView()) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Fitness Settings")
                        }
                    }
                }
                
                // MARK: - About
                Section(header: Text("About")) {
                    Link(destination: URL(string: "https://github.com/EinsPommes/even-g1-app")!) {
                        HStack {
                            Image(systemName: "swift")
                            Text("Source Code on GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Link(destination: URL(string: "mailto:feedback@even-reality.com")!) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Send Feedback")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddProfileSheet) {
                ProfileEditorView(isPresented: $showingAddProfileSheet, profile: nil)
                    .environmentObject(bleManager)
            }
            .sheet(isPresented: $showingEditProfileSheet) {
                if let profile = selectedProfile {
                    ProfileEditorView(isPresented: $showingEditProfileSheet, profile: profile)
                        .environmentObject(bleManager)
                }
            }
            .onChange(of: needsRefresh) { _ in
                // This is just a dummy to force view updates
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var bleStatusText: String {
        switch bleManager.centralState {
        case .poweredOn:
            return "On"
        case .poweredOff:
            return "Off"
        case .resetting:
            return "Resetting"
        case .unauthorized:
            return "Unauthorized"
        case .unsupported:
            return "Unsupported"
        case .unknown:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var bleStatusColor: Color {
        switch bleManager.centralState {
        case .poweredOn:
            return .green
        case .poweredOff, .unauthorized, .unsupported:
            return .red
        case .resetting, .unknown:
            return .orange
        @unknown default:
            return .orange
        }
    }
    
    private func batteryIconName(for level: Int) -> String {
        if level <= 10 {
            return "battery.0"
        } else if level <= 25 {
            return "battery.25"
        } else if level <= 50 {
            return "battery.50"
        } else if level <= 75 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
    
    private func batteryColor(for level: Int) -> Color {
        if level <= 20 {
            return .red
        } else if level <= 40 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Protocol Profile Editor

struct ProfileEditorView: View {
    @EnvironmentObject var bleManager: BLEManager
    @Binding var isPresented: Bool
    
    @State private var name: String
    @State private var serviceUUID: String
    @State private var txCharacteristic: String
    @State private var rxCharacteristic: String
    @State private var writeType: WriteType
    @State private var encoding: DataEncoding
    
    private let isEditing: Bool
    private let profileId: UUID
    
    init(isPresented: Binding<Bool>, profile: ProtocolProfile?) {
        self._isPresented = isPresented
        
        if let profile = profile {
            self._name = State(initialValue: profile.name)
            self._serviceUUID = State(initialValue: profile.serviceUUID)
            self._txCharacteristic = State(initialValue: profile.txCharacteristic)
            self._rxCharacteristic = State(initialValue: profile.rxCharacteristic ?? "")
            self._writeType = State(initialValue: profile.writeType)
            self._encoding = State(initialValue: profile.encoding)
            self.isEditing = true
            self.profileId = profile.id
        } else {
            self._name = State(initialValue: "")
            self._serviceUUID = State(initialValue: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
            self._txCharacteristic = State(initialValue: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
            self._rxCharacteristic = State(initialValue: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
            self._writeType = State(initialValue: .withoutResponse)
            self._encoding = State(initialValue: .utf8)
            self.isEditing = false
            self.profileId = UUID()
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Profile Name", text: $name)
                }
                
                Section(header: Text("Service")) {
                    TextField("Service UUID", text: $serviceUUID)
                        .font(.system(.body, design: .monospaced))
                }
                
                Section(header: Text("Characteristics")) {
                    TextField("TX Characteristic (Write)", text: $txCharacteristic)
                        .font(.system(.body, design: .monospaced))
                    
                    TextField("RX Characteristic (Notify)", text: $rxCharacteristic)
                        .font(.system(.body, design: .monospaced))
                }
                
                Section(header: Text("Write Type")) {
                    Picker("Write Type", selection: $writeType) {
                        ForEach(WriteType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Encoding")) {
                    Picker("Encoding", selection: $encoding) {
                        ForEach(DataEncoding.allCases) { encoding in
                            Text(encoding.rawValue).tag(encoding)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                        isPresented = false
                    }
                    .disabled(name.isEmpty || serviceUUID.isEmpty || txCharacteristic.isEmpty)
                }
            }
        }
    }
    
    private func saveProfile() {
        let rxUUID = rxCharacteristic.isEmpty ? nil : rxCharacteristic
        
        let profile = ProtocolProfile(
            id: profileId,
            name: name,
            serviceUUID: serviceUUID,
            txCharacteristic: txCharacteristic,
            rxCharacteristic: rxUUID,
            writeType: writeType,
            encoding: encoding,
            framing: nil,
            commands: [
                "SEND_TEXT": CommandTemplate(
                    template: "{text}",
                    description: "Send text to glasses"
                ),
                "CLEAR": CommandTemplate(
                    template: "CLEAR",
                    description: "Clear display"
                )
            ]
        )
        
        bleManager.saveProfile(profile)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
            .environmentObject(BLEManager())
            .environmentObject(AppSettings())
    }
}