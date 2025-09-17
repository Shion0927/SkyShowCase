// Notifications/NotificationSettingsView.swift
import SwiftUI
import Foundation

/// 通知設定のフォーム（中央モーダル内に埋め込んで使う）
struct NotificationSettingsView: View {
    @Binding var rule: NotificationRule
    let locale: Locale
    var onSave: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Form {
            // タイプ（チップグリッド）
            Section {
                FrequencyChipGrid(selection: $rule.frequency, locale: locale)
            }

            // 曜日選択（毎週のときのみ）
            if rule.frequency == .weekly {
                Section(header: Text(isJapanese(locale) ? "曜日" : "Weekdays")) {
                    WeekdaySelector(selected: $rule.weekdays)
                }
            }

            // しきい値（温度条件のときのみ）
            if rule.frequency == .tempAbove || rule.frequency == .tempBelow {
                Section(header: Text(isJapanese(locale) ? "しきい値 (℃)" : "Threshold (°C)")) {
                    Stepper(
                        value: Binding(
                            get: { Int(rule.temperature ?? (rule.frequency == .tempAbove ? 30 : 5)) },
                            set: { rule.temperature = Double($0) }
                        ),
                        in: -30...50
                    ) {
                        Text("\(Int(rule.temperature ?? (rule.frequency == .tempAbove ? 30 : 5)))℃")
                            .monospacedDigit()
                    }
                }
            }

            // 本日の通知（ON/OFF + 時刻）
            Section(header: Text(isJapanese(locale) ? "本日の天気を通知" : "Today")) {
                Toggle(isJapanese(locale) ? "本日の天気の通知を有効にする" : "Enable today", isOn: $rule.enableToday)
                HStack {
                    Text(isJapanese(locale) ? "時間" : "Time")
                    Spacer()
                    TimePicker(hour: $rule.todayHour, minute: $rule.todayMinute)
                        .disabled(!rule.enableToday)
                }
            }

            // 明日の通知（ON/OFF + 時刻）
            Section(header: Text(isJapanese(locale) ? "明日の天気を通知" : "Tomorrow")) {
                Toggle(isJapanese(locale) ? "明日の天気の通知を有効にする" : "Enable tomorrow", isOn: $rule.enableTomorrow)
                HStack {
                    Text(isJapanese(locale) ? "時間" : "Time")
                    Spacer()
                    TimePicker(hour: $rule.tomorrowHour, minute: $rule.tomorrowMinute)
                        .disabled(!rule.enableTomorrow)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    onSave()
                } label: {
                    Text(isJapanese(locale) ? "保存" : "Save")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        // Remove navigationTitle and toolbar for modal-only bottom buttons UI
    }
}

struct NotificationBell: View {
    @Binding var rule: NotificationRule?
    let locale: Locale
    var onOpenSettings: () -> Void   // 通知設定画面を開く（新規 or 編集）
    var onDisable: () -> Void        // 通知を解除

    var body: some View {
        Group {
            if rule == nil {
                // 設定がない場合はタップで設定画面を開く
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "bell")
                }
                .buttonStyle(.plain)
            } else {
                // 設定がある場合はメニューを表示（アイコン直下にポップ）
                Menu {
                    Button {
                        onOpenSettings()
                    } label: {
                        Text(isJapanese(locale) ? "通知を編集" : "Edit notification")
                    }

                    Button(role: .destructive) {
                        onDisable()
                    } label: {
                        Text(isJapanese(locale) ? "通知を解除" : "Disable notification")
                    }
                } label: {
                    Image(systemName: "bell.fill")
                }
                .menuIndicator(.hidden)
                // iOSではラベルのタップでメニューが開きます（chevron非表示）
            }
        }
    }
}

private struct FrequencyChipGrid: View {
    @Binding var selection: NotificationRule.Frequency
    let locale: Locale

    private var items: [(NotificationRule.Frequency, String)] {
        [
            (.daily,      isJapanese(locale) ? "毎日" : "Daily"),
            (.weekly,     isJapanese(locale) ? "毎週" : "Weekly"),
            (.oneTime,    isJapanese(locale) ? "1回のみ" : "One time"),
            (.nextDayRain,isJapanese(locale) ? "次の雨の日" : "Next rainy day"),
            (.tempAbove,  isJapanese(locale) ? "設定気温以上" : "Temp ≥"),
            (.tempBelow,  isJapanese(locale) ? "設定気温以下" : "Temp ≤")
        ]
    }

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items, id: \.0) { (freq, label) in
                let isOn = selection == freq
                Button {
                    selection = freq
                } label: {
                    Text(label)
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isOn ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isOn ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - パーツ

struct TimePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var body: some View {
        HStack {
            Picker("H", selection: $hour) {
                ForEach(0..<24, id: \.self) { Text("\($0)") }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Text(":").font(.title2).monospacedDigit()

            Picker("M", selection: $minute) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 150)
    }
}

struct WeekdaySelector: View {
    @Binding var selected: Set<Int>?
    var body: some View {
        // 1=Sun ... 7=Sat（Calendar準拠）
        let symbols = Calendar.current.shortWeekdaySymbols  // ロケールに合わせた短縮表記
        let indices = Array(1...7)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(Array(zip(indices, symbols)), id: \.0) { (w, name) in
                let isOn = (selected ?? []).contains(w)
                Button {
                    if selected == nil { selected = [] }
                    if isOn { selected!.remove(w) } else { selected!.insert(w) }
                } label: {
                    Text(name)
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isOn ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isOn ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
