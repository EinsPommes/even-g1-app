//
//  TeleprompterEngine.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import Combine
import OSLog

// Controls text flow for teleprompter
class TeleprompterEngine: ObservableObject {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.g1teleprompter", category: "TeleprompterEngine")
    
    // Text and state
    @Published var text: String = ""
    @Published var currentPosition: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var speed: Double = 1.0
    @Published var countdownActive: Bool = false
    @Published var countdownValue: Int = 3
    
    // Configuration
    var fontSizeMultiplier: Double = 1.0
    var lineSpacing: Double = 1.2
    var usesMonospaceFont: Bool = false
    var showCountdown: Bool = true
    var countdownDuration: TimeInterval = 3.0
    
    // Markers and pauses
    private var pauseMarkers: [Double] = []
    private var currentMarkerIndex: Int = 0
    
    // Timers
    private var scrollTimer: Timer?
    private var countdownTimer: Timer?
    private var lastUpdateTime: Date?
    
    // Callbacks
    var onTextComplete: (() -> Void)?
    var onPositionUpdate: ((Double) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Set defaults
        resetState()
    }
    
    // MARK: - Public Methods
    
    // Start teleprompter with text
    func start(text: String, speed: Double = 1.0) {
        self.text = text
        self.speed = speed
        self.currentPosition = 0.0
        self.isPlaying = false
        
        // Find pause markers (///)
        findPauseMarkers()
        
        if showCountdown {
            startCountdown()
        } else {
            play()
        }
        
        logger.info("Teleprompter started with \(text.count) characters at speed \(speed)")
    }
    
    // Start playback
    func play() {
        guard !isPlaying else { return }
        
        isPlaying = true
        lastUpdateTime = Date()
        
        // Create a timer for regular updates
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
    }
    
    /// Pausiert die Wiedergabe
    func pause() {
        isPlaying = false
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
    
    /// Setzt die Wiedergabe fort
    func resume() {
        play()
    }
    
    /// Stops playback and resets everything
    func stop() {
        pause()
        currentPosition = 0.0
        onPositionUpdate?(0.0)
    }
    
    /// Springt zu einer bestimmten Position im Text
    func seek(to position: Double) {
        currentPosition = max(0, min(position, Double(text.count)))
        onPositionUpdate?(currentPosition)
    }
    
    /// Jumps forward or backward by a specific offset
    func seek(offset: Double) {
        seek(to: currentPosition + offset)
    }
    
    /// Changes the playback speed
    func setSpeed(_ newSpeed: Double) {
        speed = max(0.1, min(newSpeed, 5.0))
    }
    
    /// Resets the state
    func resetState() {
        pause()
        text = ""
        currentPosition = 0.0
        speed = 1.0
        pauseMarkers = []
        currentMarkerIndex = 0
        countdownActive = false
        countdownValue = Int(countdownDuration)
    }
    
    // MARK: - Private Methods
    
    private func startCountdown() {
        countdownActive = true
        countdownValue = Int(countdownDuration)
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.countdownValue -= 1
            
            if self.countdownValue <= 0 {
                timer.invalidate()
                self.countdownActive = false
                self.play()
            }
        }
    }
    
    private func updatePosition() {
        guard isPlaying, let lastUpdate = lastUpdateTime else { return }
        
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdate)
        lastUpdateTime = now
        
        // Calculate the new position based on speed
        // Base scroll rate is 5 characters per second at speed = 1.0
        let baseScrollRate: Double = 5.0
        let newPosition = currentPosition + (deltaTime * baseScrollRate * speed)
        
        // Check if we've reached a pause marker
        if currentMarkerIndex < pauseMarkers.count && newPosition >= pauseMarkers[currentMarkerIndex] {
            currentPosition = pauseMarkers[currentMarkerIndex]
            pause()
            currentMarkerIndex += 1
            return
        }
        
        // Check if we've reached the end of the text
        if newPosition >= Double(text.count) {
            currentPosition = Double(text.count)
            pause()
            onTextComplete?()
            return
        }
        
        // Aktualisiere die Position
        currentPosition = newPosition
        onPositionUpdate?(currentPosition)
    }
    
    private func findPauseMarkers() {
        pauseMarkers = []
        currentMarkerIndex = 0
        
        // Suche nach Pausenmarkern (///)
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: "///", options: [], range: searchRange) {
            let position = Double(text.distance(from: text.startIndex, to: range.lowerBound))
            pauseMarkers.append(position)
            searchRange = range.upperBound..<text.endIndex
        }
        
        // Sortiere die Marker nach Position
        pauseMarkers.sort()
    }
}

// MARK: - Extensions

extension String {
    /// Returns the part of the string that should be displayed up to the specified position
    func visibleTextUpTo(position: Double) -> String {
        let intPosition = Int(position)
        guard intPosition <= count else { return self }
        
        let endIndex = index(startIndex, offsetBy: intPosition)
        return String(self[..<endIndex])
    }
    
    /// Returns the part of the string that should be displayed after the specified position
    func remainingTextAfter(position: Double) -> String {
        let intPosition = Int(position)
        guard intPosition < count else { return "" }
        
        let startIndex = index(self.startIndex, offsetBy: intPosition)
        return String(self[startIndex...])
    }
}
