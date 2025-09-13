//
//  DataExtension.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation

extension Data {
    /// Converts data to hex string
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined(separator: " ")
    }
    
    /// Initializes Data from hex string
    init?(hexString: String) {
        guard !hexString.isEmpty else { return nil }
        
        var data = Data()
        var hex = hexString
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
        
        // Ensure the length is even
        if hex.count % 2 != 0 {
            hex = "0" + hex
        }
        
        var i = hex.startIndex
        while i < hex.endIndex {
            let nextIndex = hex.index(i, offsetBy: 2)
            let byteString = hex[i..<nextIndex]
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            i = nextIndex
        }
        
        self = data
    }
}
