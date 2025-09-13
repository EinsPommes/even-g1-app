//
//  StringArrayTransformer.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation

/// A ValueTransformer for string arrays in CoreData
@objc(StringArrayTransformer)
class StringArrayTransformer: ValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSArray.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let stringArray = value as? [String] else {
            return nil
        }
        
        return try? NSKeyedArchiver.archivedData(withRootObject: stringArray, requiringSecureCoding: true)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            return nil
        }
        
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: data) as? [String]
    }
    
    /// Registers the transformer
    static func register() {
        let name = NSValueTransformerName(rawValue: String(describing: StringArrayTransformer.self))
        let transformer = StringArrayTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}
