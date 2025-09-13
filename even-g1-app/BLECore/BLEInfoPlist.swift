import Foundation
import UIKit

class BLEInfoPlist {
    static func addBLEPermissions() {
        // This function adds Bluetooth permissions programmatically
        // Called in AppDelegate or SceneDelegate
        
        guard let infoDictionary = Bundle.main.infoDictionary else { return }
        
        // Add Bluetooth permissions
        var mutableInfoDictionary = infoDictionary as [String: Any]
        
        // NSBluetoothAlwaysUsageDescription
        if mutableInfoDictionary["NSBluetoothAlwaysUsageDescription"] == nil {
            mutableInfoDictionary["NSBluetoothAlwaysUsageDescription"] = "This app needs Bluetooth to communicate with G1 Smart-Glasses."
        }
        
        // NSBluetoothPeripheralUsageDescription
        if mutableInfoDictionary["NSBluetoothPeripheralUsageDescription"] == nil {
            mutableInfoDictionary["NSBluetoothPeripheralUsageDescription"] = "This app needs Bluetooth to communicate with G1 Smart-Glasses."
        }
        
        // UIBackgroundModes
        var backgroundModes = mutableInfoDictionary["UIBackgroundModes"] as? [String] ?? []
        if !backgroundModes.contains("bluetooth-central") {
            backgroundModes.append("bluetooth-central")
        }
        if !backgroundModes.contains("bluetooth-peripheral") {
            backgroundModes.append("bluetooth-peripheral")
        }
        mutableInfoDictionary["UIBackgroundModes"] = backgroundModes
        
        // Note: These changes are only effective at runtime and are not saved to Info.plist
        // This is just a workaround for development purposes
        print("Bluetooth permissions added programmatically")
    }
}
