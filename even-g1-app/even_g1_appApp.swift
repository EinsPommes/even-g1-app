//
//  G1OpenTeleprompterApp.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI
import Combine
import AppIntents
import CoreBluetooth
import UIKit
import HealthKit

@main
struct G1OpenTeleprompterApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var bleManager = BLEManager()
    @StateObject private var fitnessManager = FitnessManager()
    
    var body: some Scene {
        WindowGroup {
            MainCoordinatorView()
                .environmentObject(appState)
                .environmentObject(bleManager)
                .environmentObject(fitnessManager)
                .onAppear {
                    setupAppearance()
                    
                    // Add required permissions
                    BLEInfoPlist.addBLEPermissions()
                    FitnessInfoPlist.addHealthKitPermissions()
                    
                    // Check for pending App Intents
                    AppIntentHandler.shared.checkForPendingIntents()
                    
                    // Check for data from Share Extension
                    ShareExtensionHandler.shared.checkForSharedData()
                }
                .onOpenURL { url in
                    // Handle URL schemes
                    handleURL(url)
                }
        }
        .backgroundTask(.appRefresh("com.g1teleprompter.reconnect")) { 
            await bleManager.reconnectSavedDevices()
        }
    }
    
    private func setupAppearance() {
        // Global UI settings
        UINavigationBar.appearance().tintColor = UIColor(Color.accentColor)
        
        // Appearance based on settings
        if let darkMode = appState.settings.useDarkMode {
            let userInterfaceStyle: UIUserInterfaceStyle = darkMode ? .dark : .light
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = userInterfaceStyle
        }
        
        // Register StringArrayTransformer for CoreData
        StringArrayTransformer.register()
    }
    
    private func handleURL(_ url: URL) {
        // Process URL schemes
        if url.scheme == "g1teleprompter" {
            if url.host == "share" {
                // URL from Share Extension
                ShareExtensionHandler.shared.checkForSharedData()
            }
        }
    }
}
