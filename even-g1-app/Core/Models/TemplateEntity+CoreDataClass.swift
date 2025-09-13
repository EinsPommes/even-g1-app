//
//  TemplateEntity+CoreDataClass.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//
//

import Foundation
import CoreData

@objc(TemplateEntity)
public class TemplateEntity: NSManagedObject {
    
    // Called before a new object is saved
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // Set default values for new objects
        id = UUID()
        title = ""
        body = ""
        tags = []
        favorite = false
        
        let now = Date()
        createdAt = now
        updatedAt = now
    }
    
    /// Converts the entity to a Template model
    func toTemplate() -> Template {
        return Template(
            id: id ?? UUID(),
            title: title ?? "",
            body: body ?? "",
            tags: tags ?? [],
            favorite: favorite,
            updatedAt: updatedAt ?? Date(),
            createdAt: createdAt ?? Date()
        )
    }
}
