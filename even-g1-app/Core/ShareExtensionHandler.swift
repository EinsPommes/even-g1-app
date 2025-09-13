//
//  ShareExtensionHandler.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import SwiftUI

/// Handler for data from Share Extension
class ShareExtensionHandler {
    static let shared = ShareExtensionHandler()
    
    /// Checks if data from Share Extension is available
    func checkForSharedData() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.g1teleprompter")
        
        // Check for shared text
        if let hasSharedText = sharedDefaults?.bool(forKey: "HasSharedText"), hasSharedText,
           let sharedText = sharedDefaults?.string(forKey: "SharedText") {
            
            // Reset the flag
            sharedDefaults?.set(false, forKey: "HasSharedText")
            sharedDefaults?.synchronize()
            
            // Process the shared text
            handleSharedText(sharedText)
        }
        
        // Check for shared template
        if let hasSharedTemplate = sharedDefaults?.bool(forKey: "HasSharedTemplate"), hasSharedTemplate,
           let templateData = sharedDefaults?.dictionary(forKey: "SharedTemplate"),
           let title = templateData["title"] as? String,
           let body = templateData["body"] as? String {
            
            // Reset the flag
            sharedDefaults?.set(false, forKey: "HasSharedTemplate")
            sharedDefaults?.synchronize()
            
            // Process the shared template
            handleSharedTemplate(title: title, body: body)
        }
    }
    
    /// Processes shared text
    private func handleSharedText(_ text: String) {
        // Show text in teleprompter or send it directly
        DispatchQueue.main.async {
            let appState = AppState()
            
            // Set the text for the teleprompter
            UserDefaults.standard.set(text, forKey: "TeleprompterText")
            
            // Switch to teleprompter view
            appState.selectedTab = .teleprompter
        }
    }
    
    /// Processes a shared template
    private func handleSharedTemplate(title: String, body: String) {
        // Save the template
        let template = Template(
            title: title,
            body: body
        )
        
        let templateStore = TemplateStore()
        templateStore.saveTemplate(template)
        
        // Add template to recently used
        DispatchQueue.main.async {
            let appState = AppState()
            appState.addRecentTemplate(template)
            
            // Switch to templates view
            appState.selectedTab = .templates
        }
    }
}
