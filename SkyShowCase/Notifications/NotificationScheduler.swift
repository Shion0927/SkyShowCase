// Notifications/NotificationScheduler.swift
import Foundation
import UserNotifications

/// 都市ごとの天気通知を管理するユーティリティ
struct NotificationScheduler {

    // MARK: Public API

    /// 予約済みかどうか（週次含む）を確認
    static func isScheduled(for cityId: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let base = id(for: cityId)
        return pending.contains { req in
            req.identifier == base ||
            req.identifier.hasPrefix(base + ".w") ||
            req.identifier == base + ".today" ||
            req.identifier == base + ".tomorrow"
        }
    }

    /// 予約を削除（単発＋週次すべて／配信済みも含めて消す）
    static func cancel(for cityId: Int) async {
        let center = UNUserNotificationCenter.current()
        var ids = [id(for: cityId)]
        ids.append(contentsOf: (1...7).map { id(for: cityId) + ".w\($0)" })
        ids.append(contentsOf: [id(for: cityId) + ".today", id(for: cityId) + ".tomorrow"])
        await center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// 予約をすべて削除（単発＋週次すべて）
    static func cancelAll(for cityId: Int) async {
        let center = UNUserNotificationCenter.current()
        var ids = [id(for: cityId)]
        ids.append(contentsOf: (1...7).map { id(for: cityId) + ".w\($0)" })
        ids.append(contentsOf: [id(for: cityId) + ".today", id(for: cityId) + ".tomorrow"])
        await center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// 予約をすべて削除（単発＋週次すべて）
    static func schedule(rule: NotificationRule,
                         for cityId: Int,
                         cityName: String,
                         forecast: Forecast?,
                         locale: Locale) async -> Bool {
        let center = UNUserNotificationCenter.current()

        // Permission
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if !granted { return false }
        case .denied:
            return false
        default:
            break
        }

        // 重複防止のため、まず既存をクリア
        await cancelAll(for: cityId)

        // コンテンツ共通部
        let content = UNMutableNotificationContent()
        content.title = isJapanese(locale) ? "天気の通知" : "Weather Reminder"

        // トリガーを構築
        switch rule.frequency {
        case .oneTime:
            guard let dc = nextDateComponents(hour: rule.hour, minute: rule.minute, weekday: nil) else { return true }
            content.body = defaultBody(for: forecast, cityName: cityName, locale: locale)
            let req = UNNotificationRequest(
                identifier: id(for: cityId),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            )
            try? await center.add(req)

        case .daily:
            var dc = DateComponents()
            dc.hour = rule.hour
            dc.minute = rule.minute
            content.body = defaultBody(for: forecast, cityName: cityName, locale: locale)
            let req = UNNotificationRequest(
                identifier: id(for: cityId),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            )
            try? await center.add(req)

        case .weekly:
            guard let wds = rule.weekdays, !wds.isEmpty else { return true }
            let body = defaultBody(for: forecast, cityName: cityName, locale: locale)
            for wd in wds {
                var dc = DateComponents()
                dc.weekday = wd
                dc.hour = rule.hour
                dc.minute = rule.minute
                let req = UNNotificationRequest(
                    identifier: id(for: cityId) + ".w\(wd)",
                    content: bodyContent(defaultText: body, locale: locale),
                    trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                )
                try? await center.add(req)
            }

        case .nextDayRain:
            if willRainTomorrow(forecast) {
                guard let dc = nextDateComponents(hour: rule.hour, minute: rule.minute, weekday: nil) else { return true }
                content.body = defaultBody(for: forecast, cityName: cityName, locale: locale)
                let req = UNNotificationRequest(
                    identifier: id(for: cityId),
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                )
                try? await center.add(req)
            } // 条件不成立なら登録しない（ルール保存は呼び出し側で）

        case .tempAbove:
            if meetsTemp(forecast, threshold: rule.temperature ?? 30, above: true) {
                guard let dc = nextDateComponents(hour: rule.hour, minute: rule.minute, weekday: nil) else { return true }
                content.body = defaultBody(for: forecast, cityName: cityName, locale: locale)
                let req = UNNotificationRequest(
                    identifier: id(for: cityId),
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                )
                try? await center.add(req)
            }

        case .tempBelow:
            if meetsTemp(forecast, threshold: rule.temperature ?? 5, above: false) {
                guard let dc = nextDateComponents(hour: rule.hour, minute: rule.minute, weekday: nil) else { return true }
                content.body = defaultBody(for: forecast, cityName: cityName, locale: locale)
                let req = UNNotificationRequest(
                    identifier: id(for: cityId),
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                )
                try? await center.add(req)
            }
        }

        // ここまで来たら権限はOK
        return true
    }

    // MARK: Per-day (today / tomorrow) one-shot scheduling
    static func scheduleToday(for cityId: Int, cityName: String, hour: Int, minute: Int, locale: Locale, forecast: Forecast?) async {
        guard let dc = todayDateComponents(hour: hour, minute: minute) else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = isJapanese(locale) ? "本日の天気" : "Today's Weather"
        content.body = defaultBodyToday(for: forecast, cityName: cityName, locale: locale)
        let req = UNNotificationRequest(
            identifier: id(for: cityId) + ".today",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
        )
        try? await center.add(req)
        #if DEBUG
        await debugDumpPending(for: cityId)
        #endif
    }

    static func scheduleTomorrow(for cityId: Int, cityName: String, hour: Int, minute: Int, locale: Locale, forecast: Forecast?) async {
        guard let dc = todayDateComponents(hour: hour, minute: minute) else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = isJapanese(locale) ? "明日の天気" : "Tomorrow's Weather"
        content.body = defaultBody(for: forecast, cityName: cityName, locale: locale)
        let req = UNNotificationRequest(
            identifier: id(for: cityId) + ".tomorrow",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
        )
        try? await center.add(req)
        #if DEBUG
        await debugDumpPending(for: cityId)
        #endif
    }

    static func cancelToday(for cityId: Int) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [id(for: cityId) + ".today"])
        center.removeDeliveredNotifications(withIdentifiers: [id(for: cityId) + ".today"])
    }

    static func cancelTomorrow(for cityId: Int) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [id(for: cityId) + ".tomorrow"])
        center.removeDeliveredNotifications(withIdentifiers: [id(for: cityId) + ".tomorrow"])
    }

    // MARK: Helpers

    private static func id(for cityId: Int) -> String { "forecast.reminder.\(cityId)" }

    private static func nextDateComponents(hour: Int, minute: Int, weekday: Int?) -> DateComponents? {
        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        if let weekday = weekday { dc.weekday = weekday }
        return dc
    }

    private static func todayDateComponents(hour: Int, minute: Int) -> DateComponents? {
        let now = Date()
        var cal = Calendar.current
        cal.timeZone = .current
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        var dc = DateComponents()
        dc.year = comps.year
        dc.month = comps.month
        dc.day = comps.day
        dc.hour = hour
        dc.minute = minute
        if let date = cal.date(from: dc), date > now { return dc } else { return nil }
    }

    private static func tomorrowDateComponents(hour: Int, minute: Int) -> DateComponents {
        let now = Date()
        var cal = Calendar.current
        cal.timeZone = .current
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now) {
            let comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
            var dc = DateComponents()
            dc.year = comps.year
            dc.month = comps.month
            dc.day = comps.day
            dc.hour = hour
            dc.minute = minute
            return dc
        }
        return DateComponents(hour: hour, minute: minute)
    }

    private static func bodyContent(defaultText: String, locale: Locale) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = isJapanese(locale) ? "天気の通知" : "Weather Reminder"
        c.body = defaultText
        return c
    }

    /// 明日用の本文（都市名＋天気＋最高/最低）
    private static func defaultBody(for forecast: Forecast?, cityName: String, locale: Locale) -> String {
        guard let f = forecast else {
            return isJapanese(locale) ? "天気のリマインダー" : "Weather reminder"
        }
        // 明日のデータは index 1 を参照。配列長が不足する場合は index 0 にフォールバック
        let idx = (f.daily.weather_code.count > 1 && f.daily.temperature_2m_max.count > 1 && f.daily.temperature_2m_min.count > 1) ? 1 : 0
        let code = f.daily.weather_code[idx]
        let max = f.daily.temperature_2m_max[idx]
        let min = f.daily.temperature_2m_min[idx]
        let desc = weatherDescription(from: code, locale: locale)
        if isJapanese(locale) {
            return "\(cityName)：\(desc) 最高\(Int(max))℃ / 最低\(Int(min))℃"
        } else {
            return "\(cityName): \(desc) High \(Int(max))°C / Low \(Int(min))°C"
        }
    }

    /// 本日用の本文（都市名＋天気＋最高/最低）
    private static func defaultBodyToday(for forecast: Forecast?, cityName: String, locale: Locale) -> String {
        guard let f = forecast,
              let code = f.daily.weather_code.first,
              let max = f.daily.temperature_2m_max.first,
              let min = f.daily.temperature_2m_min.first else {
            return isJapanese(locale) ? "本日の天気のリマインダー" : "Reminder for today's weather"
        }
        let desc = weatherDescription(from: code, locale: locale)
        if isJapanese(locale) {
            return "\(cityName)：\(desc) 最高\(Int(max))℃ / 最低\(Int(min))℃"
        } else {
            return "\(cityName): \(desc) High \(Int(max))°C / Low \(Int(min))°C"
        }
    }

    /// Open-Meteo weather_code を簡易的な説明に変換
    private static func weatherDescription(from code: Int, locale: Locale) -> String {
        if isJapanese(locale) {
            switch code {
            case 0: return "快晴"
            case 1: return "晴れ"
            case 2: return "薄曇り"
            case 3: return "曇天"
            case 45, 48: return "霧"
            case 51, 53, 55: return "霧雨"
            case 61, 63, 65, 80, 81, 82: return "雨"
            case 71, 73, 75, 85, 86: return "雪"
            case 95, 96, 99: return "雷雨"
            default: return "天気"
            }
        } else {
            switch code {
            case 0: return "Clear"
            case 1: return "Sunny"
            case 2: return "Partly cloudy"
            case 3: return "Cloudy"
            case 45, 48: return "Fog"
            case 51, 53, 55: return "Drizzle"
            case 61, 63, 65, 80, 81, 82: return "Rain"
            case 71, 73, 75, 85, 86: return "Snow"
            case 95, 96, 99: return "Thunderstorm"
            default: return "Weather"
            }
        }
    }

    private static func willRainTomorrow(_ forecast: Forecast?) -> Bool {
        guard let f = forecast else { return false }
        let code = f.daily.weather_code.first ?? 0
        return [61,63,65,80,81,82,95,96,99].contains(code)
    }

    private static func meetsTemp(_ forecast: Forecast?, threshold: Double, above: Bool) -> Bool {
        guard let f = forecast else { return false }
        let value = above ? (f.daily.temperature_2m_max.first ?? 0) : (f.daily.temperature_2m_min.first ?? 0)
        return above ? (value >= threshold) : (value <= threshold)
    }

    #if DEBUG
    /// 保留中の通知をダンプ（このアプリの識別子のみ）
    static func debugDumpPending(for cityId: Int? = nil) async {
        let basePrefix = "forecast.reminder"
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let targets = pending.filter { req in
            guard req.identifier.hasPrefix(basePrefix) else { return false }
            if let cityId = cityId {
                return req.identifier.contains(".\(cityId)") || req.identifier.hasSuffix("\(cityId)")
            }
            return true
        }
        print("[NotificationScheduler] Pending count=\(targets.count)")
        for r in targets {
            let trig = (r.trigger as? UNCalendarNotificationTrigger)?.dateComponents
            print("  id=\(r.identifier) title=\(r.content.title) body=\(r.content.body) dc=\(String(describing: trig))")
        }
    }
    #endif
}
