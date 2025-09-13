//
//  ContentView.swift
//  even-g1-app
//
//  Created by oxo.mika on 09/09/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var bleManager = BLEManager()
    
    var body: some View {
        MainCoordinatorView()
            .environmentObject(appState)
            .environmentObject(bleManager)
    }
}

#Preview {
    ContentView()
}
