//
//  NotificationsView.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/12/22.
//

import SwiftUI

struct NotificationsView: View {

    // MARK: - Mock data (replace later)
    private let items: [NotificationRowModel] = [
        .init(title: "帰宅前の雨", timeText: "今日 18:00", summary: "帰宅時間帯 × 雨開始60分前", state: .sent),
        .init(title: "朝の冷え込み", timeText: "今日 07:00", summary: "体感温度がしきい値を下回った", state: .sent),
        .init(title: "弱い雨", timeText: "通知せず", summary: "過去の反応から通知を抑制", state: .suppressed)
    ]

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    NavigationLink {
                        NotificationDetailView(
                            title: item.title,
                            time: item.timeText,
                            wasSent: item.state == .sent,
                            reason: item.summary,
                            level: .soft // TODO: derive from rule later
                        )
                    } label: {
                        NotificationRow(model: item)
                    }
                }
            } header: {
                Text("履歴")
            }
        }
        .navigationTitle("通知")
        .listStyle(.insetGrouped)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
