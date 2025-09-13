//
//  LocalizationExtension.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import SwiftUI

/// Extension for String to simplify localized strings usage
extension String {
    /// Returns the localized string
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized string with formatting
    func localized(_ args: CVarArg...) -> String {
        let localizedFormat = NSLocalizedString(self, comment: "")
        return String(format: localizedFormat, arguments: args)
    }
}

/// Extension for Text to simplify localized strings usage
extension Text {
    /// Creates a Text with localized string
    static func localized(_ key: String) -> Text {
        return Text(key.localized)
    }
    
    /// Creates a Text with localized string and formatting
    static func localized(_ key: String, _ args: CVarArg...) -> Text {
        return Text(key.localized(args))
    }
}
