//
//  WidgetViews.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI
import WidgetKit

// MARK: - Connection Status Widget View

struct ConnectionStatusWidgetView: View {
    var entry: ConnectionStatusProvider.Entry
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Text("G1 Status")
                    .font(.headline)
                    .padding(.top, 8)
                
                Spacer()
                
                HStack(spacing: 20) {
                    VStack {
                        Image(systemName: entry.leftConnected ? "circle.fill" : "circle")
                            .foregroundColor(entry.leftConnected ? .green : .red)
                            .font(.system(size: 12))
                        
                        Text("Left")
                            .font(.caption)
                    }
                    
                    VStack {
                        Image(systemName: entry.rightConnected ? "circle.fill" : "circle")
                            .foregroundColor(entry.rightConnected ? .green : .red)
                            .font(.system(size: 12))
                        
                        Text("Right")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                Button {
                    // Connect action
                } label: {
                    Text("Connect")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.bottom, 8)
            }
            .padding()
        }
    }
}

// MARK: - Quick Send Widget View

struct QuickSendWidgetView: View {
    var entry: QuickSendProvider.Entry
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Send")
                    .font(.headline)
                    .padding(.top, 8)
                
                if entry.recentTemplates.isEmpty {
                    Text("No recently used templates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(entry.recentTemplates.prefix(3)) { template in
                                Button {
                                    // Action executed via Intent
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(template.title)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            
                                            Text(template.previewText(maxLength: 30))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "paperplane.fill")
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                    }
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // This method was removed as it's no longer needed
}

// MARK: - Widget Previews

struct WidgetPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            ConnectionStatusWidgetView(entry: ConnectionStatusEntry(
                date: Date(),
                leftConnected: true,
                rightConnected: false
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            QuickSendWidgetView(entry: QuickSendEntry(
                date: Date(),
                recentTemplates: [
                    Template(title: "Greeting", body: "Hello and welcome!"),
                    Template(title: "Farewell", body: "Thank you for your attention."),
                    Template(title: "Note", body: "Please note the following points...")
                ]
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
