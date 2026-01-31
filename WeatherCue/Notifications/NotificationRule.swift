import Foundation

// MARK: - NotificationRule

struct NotificationRule: Codable {
    enum Frequency: String, Codable {
        case daily
        case weekly
        case oneTime
        case nextDayRain
        case tempAbove
        case tempBelow
    }

    var frequency: Frequency
    var weekdays: Set<Int>?
    var temperature: Double?

    // UI（NotificationSettingsView）で編集される項目
    var enableToday: Bool
    var todayHour: Int
    var todayMinute: Int

    var enableTomorrow: Bool
    var tomorrowHour: Int
    var tomorrowMinute: Int

    // Scheduler 互換（現状これを参照している前提）
    var hour: Int
    var minute: Int

    // MARK: - Defaults

    static var defaultRule: NotificationRule {
        NotificationRule(
            frequency: .daily,
            weekdays: nil,
            temperature: nil,
            enableToday: true,
            todayHour: 8,
            todayMinute: 0,
            enableTomorrow: false,
            tomorrowHour: 20,
            tomorrowMinute: 0,
            hour: 8,
            minute: 0
        )
    }

    // MARK: - Storage key

    private static func key(for cityId: Int) -> String {
        "notification_rule_\(cityId)"
    }

    /// 互換のため複数キーを試す（過去にキー名を変更した場合の救済）
    private static func keyCandidates(for cityId: Int) -> [String] {
        let canonical = key(for: cityId)
        return [
            canonical,
            "notificationRule_\(cityId)",
            "notification_rule-\(cityId)",
            "notification.rule.\(cityId)",
            "rule_\(cityId)"
        ]
    }
}

// MARK: - Persistence

extension NotificationRule {
    static func load(for cityId: Int) -> NotificationRule? {
        for k in keyCandidates(for: cityId) {
            guard let data = UserDefaults.standard.data(forKey: k) else { continue }
            if let decoded = try? JSONDecoder().decode(NotificationRule.self, from: data) {
                // 見つけたキーがcanonicalでない場合、canonicalへ移行保存（自動マイグレーション）
                if k != key(for: cityId) {
                    UserDefaults.standard.set(data, forKey: key(for: cityId))
                    UserDefaults.standard.removeObject(forKey: k)
                }
                return decoded
            }
        }
        return nil
    }

    static func save(_ rule: NotificationRule, for cityId: Int) {
        let k = key(for: cityId)
        let normalized = normalizeForSave(rule)
        if let data = try? JSONEncoder().encode(normalized) {
            UserDefaults.standard.set(data, forKey: k)
        }
    }

    static func delete(for cityId: Int) {
        for k in keyCandidates(for: cityId) {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }

    // MARK: - Normalize

    /// 保存前にルールを正規化（互換/安全のため）
    private static func normalizeForSave(_ rule: NotificationRule) -> NotificationRule {
        var r = rule

        // frequency に応じて不要な値を整理
        if r.frequency != .weekly {
            r.weekdays = nil
        } else {
            // weekly は曜日必須。未指定なら月〜金をデフォルト
            if r.weekdays == nil || r.weekdays?.isEmpty == true {
                r.weekdays = [2, 3, 4, 5, 6] // Mon..Fri
            }
        }

        // 温度しきい値
        if r.frequency == .tempAbove {
            if r.temperature == nil { r.temperature = 30 }
        } else if r.frequency == .tempBelow {
            if r.temperature == nil { r.temperature = 5 }
        } else {
            r.temperature = nil
        }

        // Scheduler互換: today/tomorrow の時刻を hour/minute に同期
        if r.enableToday {
            r.hour = r.todayHour
            r.minute = r.todayMinute
        } else if r.enableTomorrow {
            r.hour = r.tomorrowHour
            r.minute = r.tomorrowMinute
        }
        // 両方 false の場合は既存 hour/minute を温存

        // 範囲ガード
        r.hour = max(0, min(23, r.hour))
        r.minute = max(0, min(59, r.minute))
        r.todayHour = max(0, min(23, r.todayHour))
        r.todayMinute = max(0, min(59, r.todayMinute))
        r.tomorrowHour = max(0, min(23, r.tomorrowHour))
        r.tomorrowMinute = max(0, min(59, r.tomorrowMinute))

        return r
    }
}
