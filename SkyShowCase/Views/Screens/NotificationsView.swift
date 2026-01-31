//
//  NotificationsView.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/12/22.
//

import SwiftUI
import UserNotifications

struct NotificationsView: View {

    @Environment(AppState.self) private var appState

    // MARK: - Pending notifications (real)
    struct PendingItem: Identifiable {
        let id: String
        let title: String
        let body: String
        let timeText: String
    }

    @State private var pending: [PendingItem] = []
    @State private var errorText: String? = nil
    @State private var isScheduling: Bool = false
    @State private var history: [NotificationScheduler.ScheduleResult] = []
    @State private var isShowingSettings: Bool = false
    @State private var editingRule: NotificationRule = .defaultRule
    @State private var editingCityId: Int? = nil
    @State private var editingCityName: String = ""

    var body: some View {
        List {
            Section {
                Button {
                    Task { await scheduleForSelectedCity() }
                } label: {
                    HStack {
                        Text("通知を再スケジュール")
                        Spacer()
                        if isScheduling {
                            ProgressView()
                        }
                    }
                }
                .disabled(appState.selectedCity == nil)

                Button {
                    openSettingsForSelectedCity()
                } label: {
                    HStack {
                        Text("通知設定を開く")
                        Spacer()
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(appState.selectedCity == nil)

                Button {
                    Task { await reloadPending() }
                } label: {
                    HStack {
                        Text("登録済み通知を更新")
                        Spacer()
                    }
                }

                if let err = errorText {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if errorText != nil {
                    Button {
                        openSettingsForSelectedCity()
                    } label: {
                        Text("通知設定を開く")
                    }
                    .disabled(appState.selectedCity == nil)
                }
            } header: {
                Text("操作")
            } footer: {
                Text("選択中の都市のルールに従って、今日/明日の通知を登録します。")
            }

            Section {
                if pending.isEmpty {
                    Text("登録済みの通知はありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pending) { item in
                        let row = NotificationRowModel(
                            title: item.title,
                            timeText: item.timeText,
                            summary: item.body,
                            state: .sent
                        )
                        NavigationLink {
                            NotificationDetailView(
                                title: item.title,
                                time: item.timeText,
                                wasSent: true,
                                reason: item.body,
                                level: .soft
                            )
                        } label: {
                            NotificationRow(model: row)
                        }
                    }
                }
            } header: {
                Text("予定")
            }

            Section {
                if history.isEmpty {
                    Text("履歴はまだありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history.prefix(30)) { item in
                        let state: NotificationRowModel.State = (item.outcome == .scheduled) ? .sent : .suppressed

                        let row = NotificationRowModel(
                            title: item.title,
                            timeText: item.nextTriggerText ?? "",
                            summary: item.reason,
                            state: state
                        )

                        NavigationLink {
                            NotificationDetailView(
                                title: item.title,
                                time: item.nextTriggerText ?? "",
                                wasSent: item.outcome == .scheduled,
                                reason: item.reason,
                                level: .soft
                            )
                        } label: {
                            NotificationRow(model: row)
                        }
                    }
                }

                Button(role: .destructive) {
                    NotificationLogStore.clear()
                    history = []
                } label: {
                    Text("履歴を削除")
                }
            } header: {
                Text("履歴")
            } footer: {
                Text("scheduled / suppressed / failed の理由を記録します（直近30件を表示）。")
            }
        }
        .navigationTitle("通知")
        .listStyle(.insetGrouped)
        .task {
            await reloadPending()
            reloadHistory()
        }
        .sheet(isPresented: $isShowingSettings) {
            // selectedCity が消える可能性もあるので、editingCityId を使う
            VStack(spacing: 0) {
                HStack {
                    Text(editingCityName.isEmpty ? "通知設定" : "通知設定 — \(editingCityName)")
                        .font(.headline)
                    Spacer()
                    Button {
                        isShowingSettings = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                NotificationSettingsView(
                    rule: $editingRule,
                    locale: .current,
                    onSave: {
                        guard let cityId = editingCityId else {
                            isShowingSettings = false
                            return
                        }
                        NotificationRule.save(editingRule, for: cityId)
                        isShowingSettings = false
                        // ルール保存できたのでエラー文を消す
                        errorText = nil
                    },
                    onDelete: {
                        guard let cityId = editingCityId else {
                            isShowingSettings = false
                            return
                        }
                        NotificationRule.delete(for: cityId)
                        isShowingSettings = false
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Actions

    private func openSettingsForSelectedCity() {
        guard let city = appState.selectedCity else { return }
        editingCityId = city.id
        editingCityName = city.name
        if let existing = NotificationRule.load(for: city.id) {
            editingRule = existing
        } else {
            editingRule = .defaultRule
        }
        isShowingSettings = true
    }

    private func scheduleForSelectedCity() async {
        guard let city = appState.selectedCity else { return }
        isScheduling = true
        defer { isScheduling = false }

        do {
            // 1) request permission (non-fatal if already granted)
            try await requestNotificationPermissionIfNeeded()

            // 2) load rule for selected city
            guard let rule = NotificationRule.load(for: city.id) else {
                errorText = "通知ルールが見つかりませんでした。通知設定で保存してから再試行してください。"

                // 履歴に残す（Aを避ける方針）
                let r = NotificationScheduler.ScheduleResult(
                    id: "rule_missing.\(city.id)",
                    cityId: city.id,
                    cityName: city.name,
                    title: "(not scheduled)",
                    body: "",
                    outcome: .failed,
                    reason: "rule_missing",
                    nextTriggerText: nil
                )
                NotificationLogStore.append(r)
                reloadHistory()
                return
            }

            // 3) schedule notifications based on current forecast (returns results for logging)
            let results = await NotificationScheduler.scheduleWithResults(
                rule: rule,
                for: city.id,
                cityName: city.name,
                forecast: appState.forecast,
                locale: .current
            )
            NotificationLogStore.append(results)
            reloadHistory()

            // 4) refresh pending list
            await reloadPending()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func reloadPending() async {
        errorText = nil
        do {
            let requests = try await UNUserNotificationCenter.current().pendingNotificationRequests()
            let mapped: [PendingItem] = requests.map { req in
                let t = req.content.title
                let b = req.content.body
                let time = formatTrigger(req.trigger)
                return PendingItem(id: req.identifier, title: t.isEmpty ? "(no title)" : t, body: b, timeText: time)
            }
            // sort: timeText is not reliable for sorting, but pending count is small; keep stable order by identifier
            pending = mapped.sorted { $0.id < $1.id }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func reloadHistory() {
        history = NotificationLogStore.load()
    }

    private func requestNotificationPermissionIfNeeded() async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .denied:
            throw NSError(domain: "Notifications", code: 1, userInfo: [NSLocalizedDescriptionKey: "通知がオフになっています。設定アプリで許可してください。"])
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                throw NSError(domain: "Notifications", code: 2, userInfo: [NSLocalizedDescriptionKey: "通知が許可されませんでした。"])
            }
        @unknown default:
            return
        }
    }

    private func formatTrigger(_ trigger: UNNotificationTrigger?) -> String {
        guard let trigger else { return "" }

        if let cal = trigger as? UNCalendarNotificationTrigger {
            if let next = cal.nextTriggerDate() {
                let f = DateFormatter()
                f.locale = .current
                f.dateStyle = .none
                f.timeStyle = .short
                return f.string(from: next)
            }
            // fallback to components
            let c = cal.dateComponents
            if let h = c.hour, let m = c.minute {
                return String(format: "%02d:%02d", h, m)
            }
        }

        if let time = trigger as? UNTimeIntervalNotificationTrigger {
            let sec = Int(time.timeInterval)
            return "in \(sec)s"
        }

        return ""
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environment(AppState())
    }
}
