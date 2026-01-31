//
//  ContentView.swift
//  WeatherCue_watch
//
//  Watch Home (Summary)
//

import SwiftUI

struct WatchHomeView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                Text("今日の結論")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ConclusionCard(
                    title: "18–20時に雨",
                    message: "傘があると安心",
                    time: "18:40",
                    systemImage: "cloud.rain"
                )
            }
            .padding(12)
        }
    }
}

#Preview {
    ContentView()
}
