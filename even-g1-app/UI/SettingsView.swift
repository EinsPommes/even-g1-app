//
//  SettingsView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI
import CoreBluetooth

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bleManager: BLEManager
    
    @State private var settings: AppSettings
    @State private var showingProfileEditor = false
    @State private var editingProfile: ProtocolProfile? = nil
    @State private var needsRefresh = false
    
    init() {
        _settings = State(initialValue: AppSettings.load())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // BLE settings
                Section(header: Text("Bluetooth")) {
                    // Profile selection
                    Picker("Active Profile", selection: Binding<UUID?>(
                        get: { settings.activeProfileId },
                        set: { newValue in
                            settings.activeProfileId = newValue
                            if let id = newValue, let profile = bleManager.availableProfiles.first(where: { $0.id == id }) {
                                bleManager.activateProfile(id)
                            }
                        }
                    )) {
                        ForEach(bleManager.availableProfiles) { profile in
                            Text(profile.name).tag(profile.id as UUID?)
                        }
                    }
                    
                    Button(action: {
                        showingProfileEditor = true
                    }) {
                        Label("Create New Profile", systemImage: "plus")
                    }
                    
                    Button(action: {
                        if let activeProfile = bleManager.activeProfile {
                            editingProfile = activeProfile
                        }
                    }) {
                        Label("Edit Active Profile", systemImage: "pencil")
                    }
                    .disabled(bleManager.activeProfile == nil)
                    
                    Toggle("Auto-connect", isOn: Binding(
                        get: { settings.autoReconnect },
                        set: { 
                            settings.autoReconnect = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
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
                
                // Teleprompter settings
                Section(header: Text("Teleprompter")) {
                    HStack {
                        Text("Default Speed")
                        Spacer()
                        Text(String(format: "%.1fx", settings.defaultScrollSpeed))
                    }
                    
                    Slider(
                        value: Binding(
                            get: { settings.defaultScrollSpeed },
                            set: { 
                                settings.defaultScrollSpeed = $0
                                needsRefresh.toggle() // Force UI update
                            }
                        ),
                        in: 0.5...3.0,
                        step: 0.1
                    )
                    
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(settings.fontSizeMultiplier * 100))%")
                    }
                    
                    Slider(
                        value: Binding(
                            get: { settings.fontSizeMultiplier },
                            set: { 
                                settings.fontSizeMultiplier = $0
                                needsRefresh.toggle() // Force UI update
                            }
                        ),
                        in: 0.5...2.0,
                        step: 0.1
                    )
                    
                    HStack {
                        Text("Line Spacing")
                        Spacer()
                        Text("\(Int(settings.lineSpacing * 100))%")
                    }
                    
                    Slider(
                        value: Binding(
                            get: { settings.lineSpacing },
                            set: { 
                                settings.lineSpacing = $0
                                needsRefresh.toggle() // Force UI update
                            }
                        ),
                        in: 0.8...2.0,
                        step: 0.1
                    )
                    
                    Toggle("Monospace Font", isOn: Binding(
                        get: { settings.usesMonospaceFont },
                        set: { 
                            settings.usesMonospaceFont = $0
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
                        Stepper("Countdown: \(Int(settings.countdownDuration)) seconds", value: Binding(
                            get: { Int(settings.countdownDuration) },
                            set: { 
                                settings.countdownDuration = TimeInterval($0)
                                needsRefresh.toggle() // Force UI update
                            }
                        ), in: 1...10)
                    }
                }
                
                // General settings
                Section(header: Text("General")) {
                    Toggle("Cloud Synchronization", isOn: Binding(
                        get: { settings.useCloudSync },
                        set: { 
                            settings.useCloudSync = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    Picker("Appearance", selection: Binding(
                        get: { 
                            // Ensure we never return nil to the picker
                            settings.useDarkMode ?? false 
                        },
                        set: { 
                            // If user selects "System", we'll handle it separately
                            settings.useDarkMode = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    )) {
                        Text("Light").tag(false)
                        Text("Dark").tag(true)
                    }
                    
                    Toggle("Use System Appearance", isOn: Binding(
                        get: { settings.useDarkMode == nil },
                        set: {
                            settings.useDarkMode = $0 ? nil : false
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    Toggle("Enable Voice Input", isOn: Binding(
                        get: { settings.enableVoiceInput },
                        set: { 
                            settings.enableVoiceInput = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    Toggle("Enable Background Mode", isOn: Binding(
                        get: { settings.enableBackgroundMode },
                        set: { 
                            settings.enableBackgroundMode = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    Toggle("Enable Widgets", isOn: Binding(
                        get: { settings.enableWidgets },
                        set: { 
                            settings.enableWidgets = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    Toggle("Enable Live Activities", isOn: Binding(
                        get: { settings.enableLiveActivity },
                        set: { 
                            settings.enableLiveActivity = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    NavigationLink(destination: FitnessSettingsView()) {
                        Text("Fitness Settings")
                    }
                }
                
                // Diagnostics settings
                Section(header: Text("Diagnostics")) {
                    Toggle("Verbose Logging", isOn: Binding(
                        get: { settings.verboseLogging },
                        set: { 
                            settings.verboseLogging = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    ))
                    
                    Picker("Log Retention", selection: Binding(
                        get: { settings.logRetentionDays },
                        set: { 
                            settings.logRetentionDays = $0
                            needsRefresh.toggle() // Force UI update
                        }
                    )) {
                        Text("1 Day").tag(1)
                        Text("7 Days").tag(7)
                        Text("30 Days").tag(30)
                        Text("Unlimited").tag(365)
                    }
                    
                    NavigationLink(destination: BLEInspectorView()) {
                        Label("BLE Inspector", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    
                    Button(action: exportLogs) {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: clearLogs) {
                        Label("Clear Logs", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                }
                
                // App information
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    }
                    
                    Button(action: openSourceCode) {
                        Label("Source Code on GitHub", systemImage: "curlybraces")
                    }
                    
                    Button(action: sendFeedback) {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: settings) { newSettings in
                // Save the settings
                newSettings.save()
                appState.settings = newSettings
                
                // Force refresh UI if needed
                if needsRefresh {
                    needsRefresh = false
                }
            }
            .onAppear {
                // Refresh settings from AppState
                settings = appState.settings
            }
            .sheet(isPresented: $showingProfileEditor) {
                ProtocolProfileEditorView(
                    mode: .create,
                    onSave: { newProfile in
                        bleManager.saveProfile(newProfile)
                        settings.activeProfileId = newProfile.id
                        bleManager.activateProfile(newProfile.id)
                        showingProfileEditor = false
                    },
                    onCancel: {
                        showingProfileEditor = false
                    }
                )
            }
            .sheet(item: $editingProfile) { profile in
                ProtocolProfileEditorView(
                    mode: .edit(profile),
                    onSave: { updatedProfile in
                        bleManager.saveProfile(updatedProfile)
                        if settings.activeProfileId == updatedProfile.id {
                            bleManager.activateProfile(updatedProfile.id)
                        }
                        editingProfile = nil
                    },
                    onCancel: {
                        editingProfile = nil
                    }
                )
            }
        }
    }
    
    private func exportLogs() {
        // This function will be implemented later
    }
    
    private func clearLogs() {
        // This function will be implemented later
    }
    
    private func openSourceCode() {
        if let url = URL(string: "https://github.com/even-reality/g1-teleprompter-ios") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendFeedback() {
        if let url = URL(string: "mailto:feedback@even-reality.com?subject=G1%20OpenTeleprompter%20Feedback") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Protocol Profile Editor

struct ProtocolProfileEditorView: View {
    enum Mode {
        case create
        case edit(ProtocolProfile)
    }
    
    let mode: Mode
    let onSave: (ProtocolProfile) -> Void
    let onCancel: () -> Void
    
    @State private var name = ""
    @State private var serviceUUID = ""
    @State private var txCharacteristic = ""
    @State private var rxCharacteristic = ""
    @State private var writeType: WriteType = .withResponse
    @State private var encoding: DataEncoding = .utf8
    @State private var useFraming = false
    @State private var startBytes = ""
    @State private var endBytes = ""
    @State private var maxPacketSize = "20"
    @State private var commands: [String: CommandTemplate] = [:]
    @State private var showingCommandEditor = false
    @State private var editingCommand: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Name", text: $name)
                }
                
                Section(header: Text("BLE Configuration")) {
                    TextField("Service UUID", text: $serviceUUID)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("TX Characteristic UUID", text: $txCharacteristic)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("RX Characteristic UUID (optional)", text: $rxCharacteristic)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Picker("Write Mode", selection: $writeType) {
                        ForEach(WriteType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Picker("Encoding", selection: $encoding) {
                        ForEach(DataEncoding.allCases) { encoding in
                            Text(encoding.rawValue).tag(encoding)
                        }
                    }
                }
                
                Section(header: Text("Framing")) {
                    Toggle("Use framing", isOn: $useFraming)
                    
                    if useFraming {
                        TextField("Start Bytes (Hex)", text: $startBytes)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("End Bytes (Hex)", text: $endBytes)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("Max Packet Size", text: $maxPacketSize)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section(header: Text("Commands")) {
                    if commands.isEmpty {
                        Text("No commands defined")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(commands.keys.sorted()), id: \.self) { key in
                            if let command = commands[key] {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(key)
                                            .font(.headline)
                                        Text(command.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(command.template)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        editingCommand = key
                                    }) {
                                        Image(systemName: "pencil")
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let keys = Array(commands.keys.sorted())
                            for index in indexSet {
                                if index < keys.count {
                                    commands.removeValue(forKey: keys[index])
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        editingCommand = nil
                        showingCommandEditor = true
                    }) {
                        Label("Add Command", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Profile" : "New Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty || serviceUUID.isEmpty || txCharacteristic.isEmpty)
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .sheet(isPresented: $showingCommandEditor) {
                CommandEditorView(
                    mode: editingCommand == nil ? .create : .edit(editingCommand!, commands[editingCommand!]!),
                    onSave: { key, command in
                        commands[key] = command
                        showingCommandEditor = false
                        editingCommand = nil
                    },
                    onCancel: {
                        showingCommandEditor = false
                        editingCommand = nil
                    }
                )
            }
        }
    }
    
    private var isEditMode: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }
    
    private func setupInitialValues() {
        if case .edit(let profile) = mode {
            name = profile.name
            serviceUUID = profile.serviceUUID
            txCharacteristic = profile.txCharacteristic
            rxCharacteristic = profile.rxCharacteristic ?? ""
            writeType = profile.writeType
            encoding = profile.encoding
            
            if let framing = profile.framing {
                useFraming = true
                startBytes = framing.startBytes?.hexString ?? ""
                endBytes = framing.endBytes?.hexString ?? ""
                maxPacketSize = framing.maxPacketSize != nil ? "\(framing.maxPacketSize!)" : "20"
            } else {
                useFraming = false
            }
            
            commands = profile.commands
        } else {
            // Default values for new profiles
            name = "New Profile"
            serviceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E" // Example UUID
            txCharacteristic = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E" // Example UUID
            rxCharacteristic = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E" // Example UUID
            writeType = .withoutResponse
            encoding = .utf8
            
            // Standard commands
            commands = [
                "SEND_TEXT": CommandTemplate(
                    template: "{text}",
                    description: "Send text to glasses"
                ),
                "CLEAR": CommandTemplate(
                    template: "CLEAR",
                    description: "Clear display"
                )
            ]
        }
    }
    
    private func saveProfile() {
        // Create framing object if enabled
        let framing: Framing?
        if useFraming {
            framing = Framing(
                startBytes: Data(hexString: startBytes),
                endBytes: Data(hexString: endBytes),
                maxPacketSize: Int(maxPacketSize) ?? 20
            )
        } else {
            framing = nil
        }
        
        // Create the profile
        let profile: ProtocolProfile
        
        if case .edit(let existingProfile) = mode {
            profile = ProtocolProfile(
                id: existingProfile.id,
                name: name,
                serviceUUID: serviceUUID,
                txCharacteristic: txCharacteristic,
                rxCharacteristic: rxCharacteristic.isEmpty ? nil : rxCharacteristic,
                writeType: writeType,
                encoding: encoding,
                framing: framing,
                commands: commands
            )
        } else {
            profile = ProtocolProfile(
                name: name,
                serviceUUID: serviceUUID,
                txCharacteristic: txCharacteristic,
                rxCharacteristic: rxCharacteristic.isEmpty ? nil : rxCharacteristic,
                writeType: writeType,
                encoding: encoding,
                framing: framing,
                commands: commands
            )
        }
        
        onSave(profile)
    }
}

// MARK: - Command Editor View

struct CommandEditorView: View {
    enum Mode {
        case create
        case edit(String, CommandTemplate)
    }
    
    let mode: Mode
    let onSave: (String, CommandTemplate) -> Void
    let onCancel: () -> Void
    
    @State private var key = ""
    @State private var template = ""
    @State private var description = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Command Name")) {
                    TextField("Name (e.g. SEND_TEXT)", text: $key)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Template")) {
                    TextEditor(text: $template)
                        .frame(minHeight: 100)
                    
                    Text("Use {parameter} for placeholders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Description")) {
                    TextField("Description", text: $description)
                }
            }
            .navigationTitle(isEditMode ? "Edit Command" : "New Command")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let command = CommandTemplate(
                            template: template,
                            description: description
                        )
                        onSave(key, command)
                    }
                    .disabled(key.isEmpty || template.isEmpty)
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private var isEditMode: Bool {
        if case .edit = mode {
            return true
        }
        return false
    }
    
    private func setupInitialValues() {
        if case .edit(let commandKey, let command) = mode {
            key = commandKey
            template = command.template
            description = command.description
        }
    }
}

// MARK: - BLE Inspector View

struct BLEInspectorView: View {
    @EnvironmentObject private var bleManager: BLEManager
    
    var body: some View {
        List {
            Section(header: Text("Active Profile")) {
                if let profile = bleManager.activeProfile {
                    Text("Name: \(profile.name)")
                    Text("Service UUID: \(profile.serviceUUID)")
                    Text("TX Characteristic: \(profile.txCharacteristic)")
                    if let rx = profile.rxCharacteristic {
                        Text("RX Characteristic: \(rx)")
                    }
                    Text("Write mode: \(profile.writeType.rawValue)")
                    Text("Encoding: \(profile.encoding.rawValue)")
                    
                    if let framing = profile.framing {
                        Text("Framing: Yes")
                        if let startBytes = framing.startBytes {
                            Text("Start Bytes: \(startBytes.hexString)")
                        }
                        if let endBytes = framing.endBytes {
                            Text("End Bytes: \(endBytes.hexString)")
                        }
                        if let maxSize = framing.maxPacketSize {
                            Text("Max Packet Size: \(maxSize)")
                        }
                    } else {
                        Text("Framing: No")
                    }
                } else {
                    Text("No active profile")
                }
            }
            
            Section(header: Text("Connected Devices")) {
                if bleManager.connectedDevices.isEmpty {
                    Text("No connected devices")
                } else {
                    ForEach(bleManager.connectedDevices) { device in
                        VStack(alignment: .leading) {
                            Text(device.knownDevice.displayName)
                                .font(.headline)
                            Text("Role: \(device.knownDevice.role.rawValue)")
                            Text("ID: \(device.knownDevice.identifier)")
                            Text("RSSI: \(device.rssi) dBm")
                            if let battery = device.batteryLevel {
                                Text("Battery: \(battery)%")
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("Bluetooth Status")) {
                Text("Status: \(bleStateString(bleManager.centralState))")
                Text("Scanning: \(bleManager.isScanning ? "Yes" : "No")")
                if let error = bleManager.lastError {
                    Text("Last error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("BLE Inspector")
        .refreshable {
            // Refresh the data
        }
    }
    
    private func bleStateString(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn:
            return "Powered On"
        case .poweredOff:
            return "Powered Off"
        case .resetting:
            return "Reset"
        case .unauthorized:
            return "Not authorized"
        case .unsupported:
            return "Not supported"
        case .unknown:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Data Extension

// Data extension has been moved to a separate file: DataExtension.swift

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
            .environmentObject(BLEManager())
    }
}
