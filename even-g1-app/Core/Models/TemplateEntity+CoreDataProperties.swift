//
//  TemplateEntity+CoreDataProperties.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//
//

import Foundation
import CoreData

extension TemplateEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TemplateEntity> {
        return NSFetchRequest<TemplateEntity>(entityName: "TemplateEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var body: String?
    @NSManaged public var tags: [String]?
    @NSManaged public var favorite: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    
    // Computed properties with default values
    var safeId: UUID {
        return id ?? UUID()
    }
    
    var safeTitle: String {
        return title ?? ""
    }
    
    var safeBody: String {
        return body ?? ""
    }
    
    var safeTags: [String] {
        return tags ?? []
    }
    
    var safeCreatedAt: Date {
        return createdAt ?? Date()
    }
    
    var safeUpdatedAt: Date {
        return updatedAt ?? Date()
    }
}
