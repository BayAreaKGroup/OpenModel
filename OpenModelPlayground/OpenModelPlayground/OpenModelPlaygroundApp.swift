//
//  OpenModelPlaygroundApp.swift
//  OpenModelPlayground
//
//  Created by Seunghwa Song on 4/30/26.
//

import SwiftUI

@main
struct OpenModelPlaygroundApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
