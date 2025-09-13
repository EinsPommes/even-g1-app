//
//  AppState.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import Foundation
import Combine

// Global app state
class AppState: ObservableObject {
    // Current tab
    @Published var selectedTab: MainTab = .home
    
    // Connection status
    @Published var isConnecting: Bool = false
    
    // Teleprompter status
    @Published var isTeleprompterActive: Bool = false
    
    // Settings
    @Published var settings: AppSettings = AppSettings.load()
    
    // Recent templates
    @Published var recentTemplates: [Template] = []
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        $settings
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] settings in
                settings.save()
            }
            .store(in: &cancellables)
    }
    
    func addRecentTemplate(_ template: Template) {
        // Keep max 5 unique templates
        recentTemplates.removeAll { $0.id == template.id }
        recentTemplates.insert(template, at: 0)
        if recentTemplates.count > 5 {
            recentTemplates = Array(recentTemplates.prefix(5))
        }
    }
}

// Main navigation tabs
enum MainTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case teleprompter = "Teleprompter"
    case devices = "Devices"
    case templates = "Templates"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .home: return "house"
        case .teleprompter: return "text.viewfinder"
        case .devices: return "antenna.radiowaves.left.and.right"
        case .templates: return "doc.text"
        case .settings: return "gear"
        }
    }
}
