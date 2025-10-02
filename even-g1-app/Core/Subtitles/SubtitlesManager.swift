//
//  SubtitlesManager.swift
//  even-g1-app
//
//  Created by oxo.mika on 02/10/2025.
//

import Foundation
import Speech
import AVFoundation
import Combine
import OSLog

/// Manages speech recognition and subtitle generation
class SubtitlesManager: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.g1teleprompter", category: "SubtitlesManager")
    
    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // G1 Service
    private let g1Service = G1Service()
    
    // Published properties
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var lastSubtitle = ""
    @Published var errorMessage: String?
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    // Settings
    @Published var autoSendToGlasses = true
    @Published var selectedGlassesId: String?
    @Published var subtitleDuration: Int = 3000 // milliseconds
    @Published var maxSubtitleLength: Int = 40
    
    // Timer for subtitle updates
    private var subtitleTimer: Timer?
    private var currentSubtitleBuffer = ""
    private var subtitleQueue: [String] = []
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                
                if status != .authorized {
                    self?.errorMessage = "Speech recognition permission not granted"
                }
            }
        }
    }
    
    func startRecording() {
        // Check if already recording
        if isRecording {
            stopRecording()
            return
        }
        
        // Check authorization
        guard authorizationStatus == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }
        
        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition not available on this device"
            return
        }
        
        // Configure audio session
        do {
            try configureAudioSession()
        } catch {
            logger.error("Audio session configuration error: \(error.localizedDescription)")
            errorMessage = "Could not configure audio session: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Could not create speech recognition request"
            return
        }
        
        // Configure recognition
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Recognition error: \(error.localizedDescription)")
                self.errorMessage = "Recognition error: \(error.localizedDescription)"
                self.stopRecording()
                return
            }
            
            if let result = result {
                // Update transcribed text
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.processSubtitles(result.bestTranscription.formattedString)
                }
            }
        }
        
        // Configure audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
            isRecording = true
            errorMessage = nil
            logger.info("Speech recognition started")
        } catch {
            logger.error("Audio engine start error: \(error.localizedDescription)")
            errorMessage = "Could not start audio engine: \(error.localizedDescription)"
            stopRecording()
        }
    }
    
    func stopRecording() {
        // Stop audio engine and recognition
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Error deactivating audio session: \(error.localizedDescription)")
        }
        
        isRecording = false
        logger.info("Speech recognition stopped")
    }
    
    // MARK: - Subtitle Processing
    
    private func processSubtitles(_ text: String) {
        // Split text into sentences or phrases
        let sentences = splitIntoSentences(text)
        
        // Process each sentence
        for sentence in sentences {
            if !subtitleQueue.contains(sentence) && sentence != lastSubtitle {
                subtitleQueue.append(sentence)
            }
        }
        
        // If no timer is running, start one
        if subtitleTimer == nil {
            processNextSubtitle()
        }
    }
    
    private func processNextSubtitle() {
        guard !subtitleQueue.isEmpty else {
            subtitleTimer = nil
            return
        }
        
        // Get next subtitle
        let subtitle = subtitleQueue.removeFirst()
        lastSubtitle = subtitle
        
        // Send to glasses if enabled
        if autoSendToGlasses, let glassesId = selectedGlassesId {
            Task {
                // Format subtitle to fit on glasses display
                let formattedSubtitle = formatSubtitleForGlasses(subtitle)
                
                // Send to glasses
                let success = await g1Service.displayCentered(
                    id: glassesId,
                    textLines: [formattedSubtitle],
                    milliseconds: subtitleDuration
                )
                
                if !success {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to send subtitle to glasses"
                    }
                }
            }
        }
        
        // Schedule next subtitle
        subtitleTimer = Timer.scheduledTimer(withTimeInterval: Double(subtitleDuration) / 1000.0, repeats: false) { [weak self] _ in
            self?.processNextSubtitle()
        }
    }
    
    // MARK: - Helper Methods
    
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func splitIntoSentences(_ text: String) -> [String] {
        // Simple sentence splitting by punctuation
        let sentenceDelimiters = [".", "!", "?", ";", ":", "\n"]
        var sentences: [String] = []
        var currentSentence = ""
        
        for char in text {
            currentSentence.append(char)
            
            if sentenceDelimiters.contains(String(char)) {
                if !currentSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sentences.append(currentSentence.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentSentence = ""
                }
            }
        }
        
        // Add any remaining text as a sentence
        if !currentSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sentences.append(currentSentence.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return sentences
    }
    
    private func formatSubtitleForGlasses(_ subtitle: String) -> String {
        // Truncate if too long
        if subtitle.count > maxSubtitleLength {
            return String(subtitle.prefix(maxSubtitleLength - 3)) + "..."
        }
        return subtitle
    }
    
    // MARK: - G1 Glasses Management
    
    func scanForGlasses() {
        g1Service.lookForGlasses()
    }
    
    func getConnectedGlasses() -> [G1Glasses] {
        return g1Service.listConnectedGlasses()
    }
    
    func connectToGlasses(id: String) async -> Bool {
        return await g1Service.connect(id: id)
    }
}
