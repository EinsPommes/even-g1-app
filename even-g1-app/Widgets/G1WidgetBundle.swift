//
//  G1WidgetBundle.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI
import WidgetKit

/// Widget bundle for the G1 OpenTeleprompter app
// @main removed as it's already used in the app file
struct G1WidgetBundle: WidgetBundle {
    var body: some Widget {
        ConnectionStatusWidget()
        QuickSendWidget()
    }
}

/// Widget for G1 glasses connection status
struct ConnectionStatusWidget: Widget {
    let kind: String = "ConnectionStatusWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConnectionStatusProvider()) { entry in
            ConnectionStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("G1 Connection Status")
        .description("Shows the current connection status of G1 glasses.")
        .supportedFamilies([.systemSmall])
    }
}

/// Widget for quickly sending templates
struct QuickSendWidget: Widget {
    let kind: String = "QuickSendWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickSendProvider()) { entry in
            QuickSendWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Send")
        .description("Quickly send templates to your G1 glasses.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Connection Status Provider

struct ConnectionStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConnectionStatusEntry {
        ConnectionStatusEntry(date: Date(), leftConnected: true, rightConnected: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ConnectionStatusEntry) -> Void) {
        // Read status from UserDefaults
        let leftConnected = UserDefaults(suiteName: "group.com.g1teleprompter")?.bool(forKey: "LeftConnected") ?? false
        let rightConnected = UserDefaults(suiteName: "group.com.g1teleprompter")?.bool(forKey: "RightConnected") ?? false
        
        let entry = ConnectionStatusEntry(date: Date(), leftConnected: leftConnected, rightConnected: rightConnected)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ConnectionStatusEntry>) -> Void) {
        // Read status from UserDefaults
        let leftConnected = UserDefaults(suiteName: "group.com.g1teleprompter")?.bool(forKey: "LeftConnected") ?? false
        let rightConnected = UserDefaults(suiteName: "group.com.g1teleprompter")?.bool(forKey: "RightConnected") ?? false
        
        let entry = ConnectionStatusEntry(date: Date(), leftConnected: leftConnected, rightConnected: rightConnected)
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

struct ConnectionStatusEntry: TimelineEntry {
    let date: Date
    let leftConnected: Bool
    let rightConnected: Bool
}

// MARK: - Quick Send Provider

struct QuickSendProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickSendEntry {
        QuickSendEntry(date: Date(), recentTemplates: [
            Template(title: "Example 1", body: "This is an example text"),
            Template(title: "Example 2", body: "Another example text")
        ])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QuickSendEntry) -> Void) {
        // Read recently used templates from UserDefaults
        var recentTemplates: [Template] = []
        
        if let data = UserDefaults(suiteName: "group.com.g1teleprompter")?.data(forKey: "RecentTemplates"),
           let templates = try? JSONDecoder().decode([Template].self, from: data) {
            recentTemplates = templates
        }
        
        let entry = QuickSendEntry(date: Date(), recentTemplates: recentTemplates)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickSendEntry>) -> Void) {
        // Read recently used templates from UserDefaults
        var recentTemplates: [Template] = []
        
        if let data = UserDefaults(suiteName: "group.com.g1teleprompter")?.data(forKey: "RecentTemplates"),
           let templates = try? JSONDecoder().decode([Template].self, from: data) {
            recentTemplates = templates
        }
        
        let entry = QuickSendEntry(date: Date(), recentTemplates: recentTemplates)
        
        // Update every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

struct QuickSendEntry: TimelineEntry {
    let date: Date
    let recentTemplates: [Template]
}
