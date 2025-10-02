//
//  FormattedPage.swift
//  even-g1-app
//
//  Created by oxo.mika on 02/10/2025.
//

import Foundation

/// Defines text justification on the page
enum JustifyPage: String, Codable {
    case top
    case bottom
    case center
}

/// Defines text justification in a line
enum JustifyLine: String, Codable {
    case left
    case right
    case center
}

/// A formatted line of text with justification
struct FormattedLine: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var justify: JustifyLine
    
    init(text: String, justify: JustifyLine = .left) {
        self.text = text
        self.justify = justify
    }
}

/// A formatted page of text with multiple lines and page justification
struct FormattedPage: Codable, Identifiable, Hashable {
    var id = UUID()
    var lines: [FormattedLine]
    var justify: JustifyPage
    
    init(lines: [FormattedLine], justify: JustifyPage = .top) {
        self.lines = lines
        self.justify = justify
    }
    
    /// Creates a formatted page from plain text, with default left alignment
    static func fromPlainText(_ text: String) -> FormattedPage {
        let textLines = text.split(separator: "\n").prefix(5) // Maximum 5 lines
        let formattedLines = textLines.map { FormattedLine(text: String($0), justify: .left) }
        return FormattedPage(lines: formattedLines, justify: .top)
    }
    
    /// Creates a centered formatted page from plain text
    static func centered(_ textLines: [String]) -> FormattedPage {
        let formattedLines = textLines.prefix(5).map { FormattedLine(text: $0, justify: .center) }
        return FormattedPage(lines: formattedLines, justify: .center)
    }
}

/// A formatted page with a display duration
struct TimedFormattedPage: Codable, Identifiable, Hashable {
    var id = UUID()
    var page: FormattedPage
    var milliseconds: Int
    
    init(page: FormattedPage, milliseconds: Int = 2000) {
        self.page = page
        self.milliseconds = milliseconds
    }
}
