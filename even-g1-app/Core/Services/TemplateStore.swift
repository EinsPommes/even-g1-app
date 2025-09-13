//
//  TemplateStore.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import CoreData
import CloudKit
import Combine
import OSLog

/// Manages storage and synchronization of templates
class TemplateStore: ObservableObject {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.g1teleprompter", category: "TemplateStore")
    
    @Published var templates: [Template] = []
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private let container: NSPersistentCloudKitContainer
    private let useCloudSync: Bool
    
    // MARK: - Initialization
    
    init(useCloudSync: Bool = true) {
        self.useCloudSync = useCloudSync
        
        // Create CoreData container
        container = NSPersistentCloudKitContainer(name: "G1OpenTeleprompter")
        
        // Configure persistence options
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Enable or disable CloudKit sync
            if useCloudSync {
                storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.g1teleprompter")
            } else {
                storeDescription.cloudKitContainerOptions = nil
            }
        }
        
        // Load the container
        container.loadPersistentStores { [weak self] (_, error) in
            if let error = error {
                self?.logger.error("Error loading CoreData container: \(error.localizedDescription)")
                self?.error = error
            } else {
                self?.logger.info("CoreData container loaded successfully")
                self?.container.viewContext.automaticallyMergesChangesFromParent = true
                self?.loadTemplates()
            }
        }
        
        // Register for remote changes
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator)
            .sink { [weak self] _ in
                self?.loadTemplates()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - CRUD Operations
    
    /// Loads all templates
    func loadTemplates() {
        isLoading = true
        
        let request = NSFetchRequest<TemplateEntity>(entityName: "TemplateEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        do {
            let entities = try container.viewContext.fetch(request)
            self.templates = entities.map { $0.toTemplate() }
            self.isLoading = false
            logger.info("Templates loaded: \(self.templates.count)")
        } catch {
            logger.error("Error loading templates: \(error.localizedDescription)")
            self.error = error
            isLoading = false
        }
    }
    
    /// Saves a template
    func saveTemplate(_ template: Template) {
        let context = container.viewContext
        
        // Check if the template already exists
        let request = NSFetchRequest<TemplateEntity>(entityName: "TemplateEntity")
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            
            if let existingEntity = results.first {
                // Update existing template
                existingEntity.title = template.title
                existingEntity.body = template.body
                existingEntity.tags = template.tags
                existingEntity.favorite = template.favorite
                existingEntity.updatedAt = Date()
                existingEntity.id = template.id // Ensure ID is set
            } else {
                // Create a new template
                let newEntity = TemplateEntity(context: context)
                // Default values are set in awakeFromInsert
                
                // Override with actual values
                newEntity.id = template.id
                newEntity.title = template.title
                newEntity.body = template.body
                newEntity.tags = template.tags
                newEntity.favorite = template.favorite
                newEntity.createdAt = template.createdAt
                newEntity.updatedAt = Date()
            }
            
            try context.save()
            loadTemplates()
            logger.info("Template saved: \(template.title)")
        } catch {
            logger.error("Error saving template: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Deletes a template
    func deleteTemplate(withId id: UUID) {
        let context = container.viewContext
        
        let request = NSFetchRequest<TemplateEntity>(entityName: "TemplateEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            
            if let entityToDelete = results.first {
                context.delete(entityToDelete)
                try context.save()
                loadTemplates()
                logger.info("Template deleted: \(id)")
            }
        } catch {
            logger.error("Error deleting template: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Searches for templates
    func searchTemplates(query: String, tags: [String] = [], favoritesOnly: Bool = false) -> [Template] {
        if query.isEmpty && tags.isEmpty && !favoritesOnly {
            return templates
        }
        
        return templates.filter { template in
            // Check favorites filter
            if favoritesOnly && !template.favorite {
                return false
            }
            
            // Check tags filter
            if !tags.isEmpty && !tags.allSatisfy({ template.tags.contains($0) }) {
                return false
            }
            
            // Check search term
            if !query.isEmpty {
                let lowercasedQuery = query.lowercased()
                return template.title.lowercased().contains(lowercasedQuery) ||
                       template.body.lowercased().contains(lowercasedQuery)
            }
            
            return true
        }
    }
    
    /// Returns all used tags
    func getAllTags() -> [String] {
        var allTags = Set<String>()
        
        for template in templates {
            for tag in template.tags {
                allTags.insert(tag)
            }
        }
        
        return Array(allTags).sorted()
    }
    
    /// Updates the CloudKit synchronization status
    func updateCloudSyncStatus(enabled: Bool) {
        // This change requires a restart of the app
        UserDefaults.standard.set(enabled, forKey: "UseCloudSync")
    }
}

// MARK: - CoreData Entities
// The TemplateEntity class is now defined in separate files:
// - TemplateEntity+CoreDataClass.swift
// - TemplateEntity+CoreDataProperties.swift
