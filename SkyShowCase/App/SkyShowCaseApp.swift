//
//  SkyShowCaseApp.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/09/04.
//

import SwiftUI

@main
struct SkyShowCaseApp: App {
    @State private var state = AppState()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
        }
    }
}
