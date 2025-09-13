//
//  Template+Extension.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation

/// Extension of Template model with additional functionality
extension Template {
    /// Initializes a template with a creation date
    init(id: UUID = UUID(), title: String, body: String, tags: [String] = [], favorite: Bool = false, updatedAt: Date = Date(), createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.favorite = favorite
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }
    
    /// Creates a copy of the template
    func duplicate() -> Template {
        return Template(
            title: "\(title) (Copy)",
            body: body,
            tags: tags,
            favorite: false
        )
    }
    
    /// Returns a shortened version of the text
    func previewText(maxLength: Int = 100) -> String {
        if body.count <= maxLength {
            return body
        }
        
        let endIndex = body.index(body.startIndex, offsetBy: maxLength)
        return String(body[..<endIndex]) + "..."
    }
    
    /// Returns the number of words in the text
    var wordCount: Int {
        let components = body.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.count
    }
    
    /// Returns the estimated reading time in seconds
    var estimatedReadingTime: TimeInterval {
        // Average reading speed: 200 words per minute
        let wordsPerMinute: Double = 200
        return Double(wordCount) / wordsPerMinute * 60
    }
    
    /// Formatted reading time as string
    var formattedReadingTime: String {
        let time = estimatedReadingTime
        
        if time < 60 {
            return "< 1 min"
        } else {
            let minutes = Int(time / 60)
            return "\(minutes) min"
        }
    }
}
