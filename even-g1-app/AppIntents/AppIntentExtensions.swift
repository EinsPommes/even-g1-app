//
//  AppIntentExtensions.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import AppIntents

/// App shortcut group
struct G1TeleprompterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
            intent: SendTemplateIntent(),
            phrases: [
                "Send template to G1 with ${applicationName}",
                "Send text to my G1 with ${applicationName}",
                "Transfer template to G1 glasses with ${applicationName}"
            ],
            shortTitle: "Send Text",
            systemImageName: "paperplane.fill"
        ),
            
            AppShortcut(
            intent: StartPrompterIntent(),
            phrases: [
                "Start G1 teleprompter with ${applicationName}",
                "Open teleprompter with template in ${applicationName}",
                "Start teleprompter for G1 with ${applicationName}"
            ],
            shortTitle: "Teleprompter",
            systemImageName: "text.viewfinder"
        ),
            
            AppShortcut(
            intent: ConnectDevicesIntent(),
            phrases: [
                "Connect to G1 glasses in ${applicationName}",
                "Establish connection to G1 with ${applicationName}",
                "Connect to my G1 glasses using ${applicationName}"
            ],
            shortTitle: "Connect",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
        ]
    }
}

// MARK: - App Intent Handler

/// Handler for App Intents called within the app
class AppIntentHandler {
    static let shared = AppIntentHandler()
    
    /// Checks at app launch if an intent should be executed
    func checkForPendingIntents() {
        // Check if teleprompter should be started
        if UserDefaults.standard.bool(forKey: "StartTeleprompter") {
            UserDefaults.standard.set(false, forKey: "StartTeleprompter")
            
            if let text = UserDefaults.standard.string(forKey: "TeleprompterText"),
               let speed = UserDefaults.standard.object(forKey: "TeleprompterSpeed") as? Double {
                
                // Navigate to teleprompter and start it
                DispatchQueue.main.async {
                    let appState = AppState()
                    appState.selectedTab = .teleprompter
                    
                    // TODO: Implement a method to start the teleprompter
                }
            }
        }
    }
}
