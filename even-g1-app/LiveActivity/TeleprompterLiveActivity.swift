//
//  TeleprompterLiveActivity.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Live Activity Attributes

struct TeleprompterAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        var currentPosition: Double
        var totalLength: Double
        var speed: Double
    }
    
    var title: String
    var text: String
}

// MARK: - Live Activity Manager

class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var activity: Activity<TeleprompterAttributes>?
    
    /// Starts a Live Activity for the teleprompter
    func startActivity(title: String, text: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let attributes = TeleprompterAttributes(title: title, text: text)
        let initialState = TeleprompterAttributes.ContentState(
            isPlaying: true,
            currentPosition: 0.0,
            totalLength: Double(text.count),
            speed: 1.0
        )
        
        do {
            activity = try Activity.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )
            print("Live Activity started")
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    /// Updates the Live Activity status
    func updateActivity(isPlaying: Bool, currentPosition: Double, speed: Double) {
        guard let activity = activity else { return }
        
        let updatedState = TeleprompterAttributes.ContentState(
            isPlaying: isPlaying,
            currentPosition: currentPosition,
            totalLength: activity.contentState.totalLength,
            speed: speed
        )
        
        Task {
            await activity.update(using: updatedState)
        }
    }
    
    /// Ends the Live Activity
    func endActivity() {
        Task {
            await activity?.end(dismissalPolicy: .immediate)
            activity = nil
        }
    }
}

// MARK: - Live Activity View

struct TeleprompterLiveActivityView: View {
    let context: ActivityViewContext<TeleprompterAttributes>
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "text.viewfinder")
                    .font(.headline)
                
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(Int(context.state.currentPosition * 100 / max(1, context.state.totalLength)))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            ProgressView(value: context.state.currentPosition, total: context.state.totalLength)
                .progressViewStyle(.linear)
                .tint(.accentColor)
            
            HStack {
                // Back button
                Button {
                    // This action is executed via the Intent handler in the app
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                
                // Play/Pause button
                Button {
                    // This action is executed via the Intent handler in the app
                } label: {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                
                // Forward button
                Button {
                    // This action is executed via the Intent handler in the app
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                // Speed
                Text("\(String(format: "%.1fx", context.state.speed))")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                    )
            }
        }
        .padding()
    }
}

// MARK: - Live Activity Configuration

struct TeleprompterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TeleprompterAttributes.self) { context in
            TeleprompterLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "text.viewfinder")
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.currentPosition * 100 / max(1, context.state.totalLength)))%")
                }
                
                DynamicIslandExpandedRegion(.center) {
                    ProgressView(value: context.state.currentPosition, total: context.state.totalLength)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Button {
                            // Back action
                        } label: {
                            Image(systemName: "backward.fill")
                        }
                        
                        Spacer()
                        
                        Button {
                            // Play/Pause action
                        } label: {
                            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                        }
                        
                        Spacer()
                        
                        Button {
                            // Forward action
                        } label: {
                            Image(systemName: "forward.fill")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } compactLeading: {
                Image(systemName: "text.viewfinder")
            } compactTrailing: {
                Text("\(Int(context.state.currentPosition * 100 / max(1, context.state.totalLength)))%")
                    .font(.caption)
            } minimal: {
                Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
            }
        }
    }
}

// MARK: - Preview
// Temporarily disabled until the app compiles

/*
// For the Live Activity preview, we need Xcode 15+ and iOS 16.1+
// and correctly integrate the corresponding APIs.
// This will be implemented in a later version.
*/
