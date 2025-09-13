//
//  TeleprompterView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI
import Combine

struct TeleprompterView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bleManager: BLEManager
    
    @StateObject private var engine = TeleprompterEngine()
    @State private var text: String = ""  // Text content for the teleprompter
    @State private var isEditing: Bool = true
    @State private var showSettings: Bool = false
    @State private var mirrorText: Bool = false
    @State private var invertColors: Bool = false
    @State private var isSendingToGlasses: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isEditing {
                    editorView
                } else {
                    teleprompterView
                }
            }
            .navigationTitle("Teleprompter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isEditing {
                        Button(action: {
                            isEditing = true
                            engine.stop()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button(action: {
                            showSettings.toggle()
                        }) {
                            Image(systemName: "gear")
                        }
                    } else {
                        HStack {
                            Button(action: {
                                mirrorText.toggle()
                            }) {
                                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                            }
                            
                            Button(action: {
                                invertColors.toggle()
                            }) {
                                Image(systemName: "circle.lefthalf.filled")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                TeleprompterSettingsView(
                    fontSizeMultiplier: $engine.fontSizeMultiplier,
                    lineSpacing: $engine.lineSpacing,
                    usesMonospaceFont: $engine.usesMonospaceFont,
                    showCountdown: $engine.showCountdown,
                    countdownDuration: $engine.countdownDuration
                )
            }
            .onAppear {
                // Load settings from app settings
                engine.fontSizeMultiplier = appState.settings.fontSizeMultiplier
                engine.lineSpacing = appState.settings.lineSpacing
                engine.usesMonospaceFont = appState.settings.usesMonospaceFont
                engine.showCountdown = appState.settings.showCountdown
                engine.countdownDuration = appState.settings.countdownDuration
                
                // Load text from app state if available
                if !appState.teleprompterText.isEmpty {
                    text = appState.teleprompterText
                    appState.teleprompterText = ""  // Clear after using
                }
                
                // Set completion callback
                engine.onTextComplete = {
                    sendCurrentTextToGlasses()
                }
            }
        }
    }
    
    // MARK: - Editor View
    
    private var editorView: some View {
        VStack {
            TextEditor(text: $text)
                .font(.body)
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .padding()
            
            HStack {
                Button(action: {
                    text = ""
                }) {
                    Text("Clear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(text.isEmpty)
                
                Button(action: sendCurrentTextToGlasses) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send to Glasses")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(text.isEmpty || bleManager.connectedDevices.isEmpty)
            }
            .padding(.horizontal)
            
            Button(action: startTeleprompter) {
                Text("Start Teleprompter")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .disabled(text.isEmpty)
        }
    }
    
    // MARK: - Teleprompter View
    
    private var teleprompterView: some View {
        ZStack {
            // Background
            Color.black
                .edgesIgnoringSafeArea(.all)
                .opacity(invertColors ? 0.0 : 1.0)
            
            Color.white
                .edgesIgnoringSafeArea(.all)
                .opacity(invertColors ? 1.0 : 0.0)
            
            VStack {
                // Countdown display
                if engine.countdownActive {
                    Text("\(engine.countdownValue)")
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundColor(invertColors ? .black : .white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Teleprompter text
                    GeometryReader { geometry in
                        ScrollView {
                            VStack(spacing: 0) {
                                // Upper spacing for scrolling
                                Spacer()
                                    .frame(height: geometry.size.height / 2)
                                
                                // Text
                                Text(engine.text)
                                    .font(engine.usesMonospaceFont ? 
                                          .system(size: 24 * engine.fontSizeMultiplier, weight: .regular, design: .monospaced) :
                                          .system(size: 24 * engine.fontSizeMultiplier, weight: .regular))
                                    .lineSpacing(8 * engine.lineSpacing)
                                    .foregroundColor(invertColors ? .black : .white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .rotation3DEffect(
                                        mirrorText ? .degrees(180) : .degrees(0),
                                        axis: (x: 0, y: 1, z: 0)
                                    )
                                
                                // Lower spacing for scrolling
                                Spacer()
                                    .frame(height: geometry.size.height / 2)
                            }
                            .frame(width: geometry.size.width)
                            .offset(y: -CGFloat(engine.currentPosition) * 0.5) // Scrolling offset
                        }
                        .disabled(true) // Disable manual scrolling
                    }
                }
                
                // Controls
                VStack {
                    // Speed slider
                    HStack {
                        Image(systemName: "tortoise")
                        Slider(value: $engine.speed, in: 0.1...3.0, step: 0.1)
                            .accentColor(invertColors ? .black : .white)
                        Image(systemName: "hare")
                    }
                    .padding(.horizontal)
                    .foregroundColor(invertColors ? .black : .white)
                    
                    // Transport controls
                    HStack(spacing: 20) {
                        Button(action: {
                            engine.seek(offset: -100)
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(invertColors ? .black : .white)
                        }
                        
                        Button(action: {
                            if engine.isPlaying {
                                engine.pause()
                            } else {
                                engine.resume()
                            }
                        }) {
                            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                                .foregroundColor(invertColors ? .black : .white)
                        }
                        
                        Button(action: {
                            engine.seek(offset: 100)
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(invertColors ? .black : .white)
                        }
                    }
                    .padding()
                    
                    // Send button
                    Button(action: sendCurrentTextToGlasses) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send to Glasses")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(bleManager.connectedDevices.isEmpty || isSendingToGlasses)
                    .padding(.bottom)
                }
                .background(
                    Rectangle()
                        .fill(invertColors ? Color.white.opacity(0.9) : Color.black.opacity(0.9))
                        .edgesIgnoringSafeArea(.bottom)
                )
            }
        }
        .statusBar(hidden: true)
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let verticalAmount = value.translation.height
                    let horizontalAmount = value.translation.width
                    
                    if abs(horizontalAmount) > abs(verticalAmount) {
                        // Horizontal gesture
                        if horizontalAmount < 0 {
                            // Swipe left: increase speed
                            engine.setSpeed(engine.speed + 0.1)
                        } else {
                            // Swipe right: decrease speed
                            engine.setSpeed(engine.speed - 0.1)
                        }
                    } else {
                        // Vertical gesture
                        if verticalAmount < 0 {
                            // Swipe up: jump forward
                            engine.seek(offset: 100)
                        } else {
                            // Swipe down: jump backward
                            engine.seek(offset: -100)
                        }
                    }
                }
        )
        .gesture(
            TapGesture()
                .onEnded {
                    if engine.isPlaying {
                        engine.pause()
                    } else {
                        engine.resume()
                    }
                }
        )
    }
    
    // MARK: - Actions
    
    private func startTeleprompter() {
        guard !text.isEmpty else { return }
        
        isEditing = false
        engine.start(text: text, speed: appState.settings.defaultScrollSpeed)
    }
    
    private func sendCurrentTextToGlasses() {
        guard !text.isEmpty, !bleManager.connectedDevices.isEmpty else { return }
        
        isSendingToGlasses = true
        
        Task {
            let results = await bleManager.broadcastText(text)
            
            // Check for errors
            let hasErrors = results.values.contains { result in
                if case .failure = result {
                    return true
                }
                return false
            }
            
            await MainActor.run {
                isSendingToGlasses = false
                
                // Add to recent templates if sent successfully
                if !hasErrors && !text.isEmpty {
                    let template = Template(
                        title: "Teleprompter Text",
                        body: text
                    )
                    appState.addRecentTemplate(template)
                }
            }
        }
    }
}

// MARK: - Teleprompter Settings View

struct TeleprompterSettingsView: View {
    @Binding var fontSizeMultiplier: Double
    @Binding var lineSpacing: Double
    @Binding var usesMonospaceFont: Bool
    @Binding var showCountdown: Bool
    @Binding var countdownDuration: TimeInterval
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Text")) {
                    VStack {
                        Text("Font Size")
                        Slider(value: $fontSizeMultiplier, in: 0.5...2.0, step: 0.1)
                        Text("\(Int(fontSizeMultiplier * 100))%")
                            .font(.caption)
                    }
                    
                    VStack {
                        Text("Line Spacing")
                        Slider(value: $lineSpacing, in: 0.8...2.0, step: 0.1)
                        Text("\(Int(lineSpacing * 100))%")
                            .font(.caption)
                    }
                    
                    Toggle("Monospace Font", isOn: $usesMonospaceFont)
                }
                
                Section(header: Text("Countdown")) {
                    Toggle("Show Countdown", isOn: $showCountdown)
                    
                    if showCountdown {
                        Stepper("Duration: \(Int(countdownDuration)) seconds", value: Binding(
                            get: { Int(countdownDuration) },
                            set: { countdownDuration = TimeInterval($0) }
                        ), in: 1...10)
                    }
                }
            }
            .navigationTitle("Teleprompter Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

struct TeleprompterView_Previews: PreviewProvider {
    static var previews: some View {
        TeleprompterView()
            .environmentObject(AppState())
            .environmentObject(BLEManager())
    }
}
