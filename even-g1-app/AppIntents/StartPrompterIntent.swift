//
//  StartPrompterIntent.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import AppIntents
import SwiftUI

/// Intent to start the teleprompter with a template or custom text
struct StartPrompterIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Teleprompter"
    static var description: IntentDescription = IntentDescription("Starts the teleprompter with a template or custom text")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Start teleprompter with \(\.$template)") {
            \.$customText
            \.$speed
            \.$autoSendToGlasses
        }
    }
    
    @Parameter(title: "Template", description: "The template to use")
    var template: TemplateIntentEntity?
    
    @Parameter(title: "Custom Text", description: "Custom text for the teleprompter (optional)")
    var customText: String?
    
    @Parameter(title: "Speed", description: "Scroll speed (0.5 - 3.0)")
    var speed: Double?
    
    @Parameter(title: "Send to Glasses", description: "Automatically send text to G1 glasses")
    var autoSendToGlasses: Bool?
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let appState = AppState()
        
        // Determine text to use
        let prompterText: String
        
        if let customText = customText, !customText.isEmpty {
            prompterText = customText
        } else if let template = template {
            prompterText = template.body
            
            // Add template to recently used
            appState.addRecentTemplate(template.toTemplate())
        } else {
            return .result(dialog: "No text specified for the teleprompter.")
        }
        
        // Determine scroll speed
        let prompterSpeed = speed ?? appState.settings.defaultScrollSpeed
        
        // Set teleprompter status
        appState.isTeleprompterActive = true
        
        // Send text to glasses if requested
        if autoSendToGlasses == true {
            let bleManager = BLEManager()
            
            if !bleManager.connectedDevices.isEmpty {
                _ = await bleManager.broadcastText(prompterText)
            }
        }
        
        // Open app and switch to teleprompter view
        await AppIntentCoordinator.shared.startTeleprompter(text: prompterText, speed: prompterSpeed)
        
        return .result(dialog: "Teleprompter started.")
    }
}

// MARK: - App Intent Coordinator

/// Coordinator for App Intents to control the app
class AppIntentCoordinator {
    static let shared = AppIntentCoordinator()
    
    @MainActor
    func startTeleprompter(text: String, speed: Double) async {
        // This function will be implemented later to open the app
        // and navigate to the teleprompter view
        
        // For now, we just set the values in UserDefaults that can be
        // read when the app starts
        UserDefaults.standard.set(text, forKey: "TeleprompterText")
        UserDefaults.standard.set(speed, forKey: "TeleprompterSpeed")
        UserDefaults.standard.set(true, forKey: "StartTeleprompter")
    }
}
