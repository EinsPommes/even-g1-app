//
//  AccessibilityExtension.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import SwiftUI

/// Extension for View to simplify accessibility features
extension View {
    /// Adds an accessibility label
    func accessibilityLabel(_ key: String) -> some View {
        return self.accessibility(label: Text(key.localized))
    }
    
    /// Adds an accessibility hint
    func accessibilityHint(_ key: String) -> some View {
        return self.accessibility(hint: Text(key.localized))
    }
    
    /// Adds an accessibility value
    func accessibilityValue(_ key: String) -> some View {
        return self.accessibility(value: Text(key.localized))
    }
    
    /// Adds both accessibility label and hint
    func accessibilityElement(_ labelKey: String, hint hintKey: String) -> some View {
        return self
            .accessibility(label: Text(labelKey.localized))
            .accessibility(hint: Text(hintKey.localized))
    }
    
    /// Adds dynamic type size support
    func dynamicTypeSize() -> some View {
        return self.dynamicTypeSize(.xSmall ... .accessibility5)
    }
    
    /// Adds accessibility traits
    func accessibilityTraits(_ traits: AccessibilityTraits) -> some View {
        return self.accessibilityAddTraits(traits)
    }
    
    /// Adds accessibility identifier (for UI tests)
    func accessibilityID(_ id: String) -> some View {
        return self.accessibilityIdentifier(id)
    }
}
