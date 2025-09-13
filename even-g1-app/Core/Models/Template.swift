//
//  Template.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import CloudKit

/// Template for teleprompter texts
struct Template: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var tags: [String]
    var favorite: Bool
    var updatedAt: Date
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, body: String, tags: [String] = [], favorite: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.favorite = favorite
        self.updatedAt = Date()
        self.createdAt = Date()
    }
    
    /// Replaces placeholders in text with specified values
    func applyPlaceholders(_ values: [String: String]) -> String {
        var result = body
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
    
    /// Extracts all placeholders from text
    func extractPlaceholders() -> [String] {
        let pattern = "\\{([^\\}]+)\\}"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        
        guard let matches = regex?.matches(in: body, range: range) else { return [] }
        
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: body) else { return nil }
            return String(body[range])
        }
    }
}

/// Extension for CloudKit integration
extension Template {
    init?(record: CKRecord) {
        guard let title = record["title"] as? String,
              let body = record["body"] as? String,
              let updatedAt = record["updatedAt"] as? Date,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }
        
        self.id = record.recordID.recordName.isEmpty ? UUID() : UUID(uuidString: record.recordID.recordName) ?? UUID()
        self.title = title
        self.body = body
        self.tags = record["tags"] as? [String] ?? []
        self.favorite = record["favorite"] as? Bool ?? false
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "Template", recordID: recordID)
        
        record["title"] = title
        record["body"] = body
        record["tags"] = tags
        record["favorite"] = favorite
        record["updatedAt"] = updatedAt
        record["createdAt"] = createdAt
        
        return record
    }
}
