//
//  ConclusionCard.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/12/23.
//

import SwiftUI

struct ConclusionCard: View {

    let title: String
    let message: String
    let time: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)

                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

#Preview {
    ConclusionCard(
        title: "18–20時に雨",
        message: "傘があると安心",
        time: "18:40",
        systemImage: "cloud.rain"
    )
}
