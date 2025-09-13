//
//  SendTemplateIntent.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import AppIntents
import SwiftUI

/// Intent to send a template to the G1 glasses
struct SendTemplateIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Template to G1"
    static var description: IntentDescription = IntentDescription("Sends a saved template to the G1 glasses")
    
    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$template) to G1 glasses") {
            \.$customText
        }
    }
    
    @Parameter(title: "Template", description: "The template to send")
    var template: TemplateIntentEntity?
    
    @Parameter(title: "Custom Text", description: "Custom text to send (optional)")
    var customText: String?
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let bleManager = BLEManager()
        let appState = AppState()
        
        // Check if devices are connected
        if bleManager.connectedDevices.isEmpty {
            // Try to connect to known devices
            await bleManager.reconnectSavedDevices()
            
            // Wait briefly and check again
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            if bleManager.connectedDevices.isEmpty {
                return .result(dialog: "No G1 glasses connected. Please connect the glasses in the app.")
            }
        }
        
        // Determine text to send
        let textToSend: String
        
        if let customText = customText, !customText.isEmpty {
            textToSend = customText
        } else if let template = template {
            textToSend = template.body
            
            // Add template to recently used
            appState.addRecentTemplate(template.toTemplate())
        } else {
            return .result(dialog: "No text specified to send.")
        }
        
        // Send the text
        let results = await bleManager.broadcastText(textToSend)
        
        // Check for errors
        let hasErrors = results.values.contains { result in
            if case .failure = result {
                return true
            }
            return false
        }
        
        if hasErrors {
            return .result(dialog: "There were problems sending the text.")
        } else {
            return .result(dialog: "Text successfully sent to G1 glasses.")
        }
    }
}

// MARK: - Template Intent Entity

/// A simplified version of Template for App Intents
struct TemplateIntentEntity: AppEntity {
    var id: UUID
    var title: String
    var body: String
    var tags: [String]
    var favorite: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(template: Template) {
        self.id = template.id
        self.title = template.title
        self.body = template.body
        self.tags = template.tags
        self.favorite = template.favorite
        self.createdAt = template.createdAt
        self.updatedAt = template.updatedAt
    }
    
    // Convert back to Template
    func toTemplate() -> Template {
        return Template(
            id: id,
            title: title,
            body: body,
            tags: tags,
            favorite: favorite,
            updatedAt: updatedAt,
            createdAt: createdAt
        )
    }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Template")
    
    static var defaultQuery = TemplateIntentQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

// MARK: - Template Intent Query

struct TemplateIntentQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TemplateIntentEntity] {
        let templateStore = TemplateStore()
        await templateStore.loadTemplates()
        
        return templateStore.templates
            .filter { identifiers.contains($0.id) }
            .map { TemplateIntentEntity(template: $0) }
    }
    
    func suggestedEntities() async throws -> [TemplateIntentEntity] {
        let templateStore = TemplateStore()
        await templateStore.loadTemplates()
        
        return templateStore.templates
            .filter { $0.favorite }
            .prefix(5)
            .map { TemplateIntentEntity(template: $0) }
    }
}
