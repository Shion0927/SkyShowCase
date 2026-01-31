// Notifications/NotificationScheduler.swift
import Foundation
import UserNotifications

/// 都市ごとの天気通知を管理するユーティリティ
struct NotificationScheduler {

    // MARK: - Schedule Results (for logging)

    enum ScheduleOutcome: String, Codable {
        case scheduled
        case suppressed
        case failed
    }

    struct ScheduleResult: Identifiable, Codable {
        let id: String                 // notification request identifier
        let cityId: Int
        let cityName: String
        let title: String
        let body: String
        let outcome: ScheduleOutcome
        let reason: String
        let nextTriggerText: String?
        let createdAt: Date

        init(id: String,
             cityId: Int,
             cityName: String,
             title: String,
             body: String,
             outcome: ScheduleOutcome,
             reason: String,
             nextTriggerText: String?) {
            self.id = id
            self.cityId = cityId
            self.cityName = cityName
            self.title = title
            self.body = body
            self.outcome = outcome
            self.reason = reason
            self.nextTriggerText = nextTriggerText
            self.createdAt = Date()
        }
    }

    // MARK: Public API

    /// 予約済みかどうか（週次含む）を確認
    static func isScheduled(for cityId: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let base = id(for: cityId)
        return pending.contains { req in
            req.identifier == base || req.identifier.hasPrefix(base + ".w") || req.identifier == base + ".today" ||
            req.identifier == base + ".tomorrow"
        }
    }


    /// 予約をすべて削除（単発＋週次すべて）
    static func cancelAll(for cityId: Int) async {
        let center = UNUserNotificationCenter.current()
        var ids = [id(for: cityId)]
        ids.append(contentsOf: (1...7).map { id(for: cityId) + ".w\($0)" })
        ids.append(contentsOf: [id(for: cityId) + ".today", id(for: cityId) + ".tomorrow"])
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// 予約をすべて削除（単発＋週次すべて）
    static func schedule(rule: NotificationRule,
                         for cityId: Int,
                         cityName: String,
                         forecast: WeatherResponse?,
                         locale: Locale) async -> Bool {
        let results = await scheduleWithResults(
            rule: rule,
            for: cityId,
            cityName: cityName,
            forecast: forecast,
            locale: locale
        )
        return results.contains { $0.outcome == .scheduled }
    }

    /// 予約結果を返す（ログ用）。scheduled / suppressed / failed を区別する。
    static func scheduleWithResults(rule: NotificationRule,
                                    for cityId: Int,
                                    cityName: String,
                                    forecast: WeatherResponse?,
                                    locale: Locale) async -> [ScheduleResult] {
        let center = UNUserNotificationCenter.current()
        var results: [ScheduleResult] = []

        // Permission
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if !granted {
                results.append(
                    .init(id: id(for: cityId), cityId: cityId, cityName: cityName,
                          title: String(localized: .init("notification.title.reminder")),
                          body: String(localized: .init("notification.body.reminder_default")),
                          outcome: .failed,
                          reason: "permission_not_granted",
                          nextTriggerText: nil)
                )
                return results
            }
        case .denied:
            results.append(
                .init(id: id(for: cityId), cityId: cityId, cityName: cityName,
                      title: String(localized: .init("notification.title.reminder")),
                      body: String(localized: .init("notification.body.reminder_default")),
                      outcome: .failed,
                      reason: "permission_denied",
                      nextTriggerText: nil)
            )
            return results
        default:
            break
        }

        // 重複防止のため、まず既存をクリア
        await cancelAll(for: cityId)

        // Insight tuning (MVP): -1 = notify less, 0 = normal, +1 = notify more
        let tuningBias = InsightTuningStore.loadBias(cityId: cityId)

        // コンテンツ共通部
        let baseTitle = String(localized: .init("notification.title.reminder"))

        // Helper to add a request + record result
        func addRequest(identifier: String, title: String, body: String, trigger: UNNotificationTrigger?, reason: String) async {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            do {
                try await center.add(req)
                let next = nextTriggerText(from: trigger, locale: locale)
                results.append(.init(id: identifier, cityId: cityId, cityName: cityName, title: title, body: body, outcome: .scheduled, reason: reason, nextTriggerText: next))
            } catch {
                results.append(.init(id: identifier, cityId: cityId, cityName: cityName, title: title, body: body, outcome: .failed, reason: "add_failed: \(error.localizedDescription)", nextTriggerText: nil))
            }
        }

        // トリガーを構築
        switch rule.frequency {
        case .oneTime:
            let body = defaultBody(for: forecast, cityName: cityName, locale: locale)
            if let dc = todayDateComponents(hour: rule.hour, minute: rule.minute) {
                await addRequest(
                    identifier: id(for: cityId),
                    title: baseTitle,
                    body: body,
                    trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false),
                    reason: "one_time"
                )
            } else {
                // already passed today -> schedule next minute so it still fires today
                var cal = Calendar.current
                cal.timeZone = .current
                let fire = cal.date(byAdding: .minute, value: 1, to: Date()) ?? Date().addingTimeInterval(60)
                let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                await addRequest(
                    identifier: id(for: cityId),
                    title: baseTitle,
                    body: body,
                    trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false),
                    reason: "one_time_asap"
                )
            }

        case .daily:
            var dc = DateComponents()
            dc.hour = rule.hour
            dc.minute = rule.minute
            let body = defaultBody(for: forecast, cityName: cityName, locale: locale)
            await addRequest(
                identifier: id(for: cityId),
                title: baseTitle,
                body: body,
                trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true),
                reason: "daily"
            )

        case .weekly:
            guard let wds = rule.weekdays, !wds.isEmpty else {
                results.append(.init(id: id(for: cityId), cityId: cityId, cityName: cityName, title: baseTitle, body: String(localized: .init("notification.body.reminder_default")), outcome: .failed, reason: "weekly_no_weekdays", nextTriggerText: nil))
                return results
            }
            let body = defaultBody(for: forecast, cityName: cityName, locale: locale)
            for wd in wds {
                var dc = DateComponents()
                dc.weekday = previousWeekday(wd)
                dc.hour = rule.hour
                dc.minute = rule.minute
                await addRequest(
                    identifier: id(for: cityId) + ".w\(wd)",
                    title: baseTitle,
                    body: body,
                    trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true),
                    reason: "weekly"
                )
            }

        case .nextDayRain:
            // bias=-1 => notify less: only notify on heavier precipitation
            let tomorrowWx = tomorrowWxCode(forecast)
            let willNotify: Bool = {
                guard let wx = tomorrowWx else { return false }
                if tuningBias <= -1 {
                    return isHeavyPrecipitation(wx)
                }
                return WXWeatherCode.isPrecipitation(wx)
            }()

            if willNotify {
                let body = defaultBody(for: forecast, cityName: cityName, locale: locale)
                if let dc = todayDateComponents(hour: rule.hour, minute: rule.minute) {
                    await addRequest(
                        identifier: id(for: cityId),
                        title: baseTitle,
                        body: body,
                        trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false),
                        reason: "next_day_rain(bias=\(tuningBias),wx=\(tomorrowWx ?? -9999))"
                    )
                } else {
                    var cal = Calendar.current
                    cal.timeZone = .current
                    let fire = cal.date(byAdding: .minute, value: 1, to: Date()) ?? Date().addingTimeInterval(60)
                    let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    await addRequest(
                        identifier: id(for: cityId),
                        title: baseTitle,
                        body: body,
                        trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false),
                        reason: "next_day_rain_asap(bias=\(tuningBias),wx=\(tomorrowWx ?? -9999))"
                    )
                }
            } else {
                results.append(
                    .init(
                        id: id(for: cityId),
                        cityId: cityId,
                        cityName: cityName,
                        title: baseTitle,
                        body: "",
                        outcome: .suppressed,
                        reason: "next_day_rain_condition_false(bias=\(tuningBias),wx=\(tomorrowWx ?? -9999))",
                        nextTriggerText: nil
                    )
                )
            }

        case .tempAbove:
            let base = Double(rule.temperature ?? 30)
            // bias=-1 => harder to trigger (need hotter) / bias=+1 => easier to trigger
            let th = base + Double(-tuningBias) * 2.0
            if meetsTemp(forecast, threshold: th, above: true) {
                let body = defaultBodyToday(for: forecast, cityName: cityName, locale: locale)
                if let dc = todayDateComponents(hour: rule.hour, minute: rule.minute) {
                    await addRequest(
                        identifier: id(for: cityId),
                        title: baseTitle,
                        body: body,
                        trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false),
                        reason: "temp_above(bias=\(tuningBias),th=\(Int(th)))"
                    )
                } else {
                    var cal = Calendar.current
                    cal.timeZone = .current
                    let fire = cal.date(byAdding: .minute, value: 1, to: Date()) ?? Date().addingTimeInterval(60)
                    let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    await addRequest(
                        identifier: id(for: cityId),
                        title: baseTitle,
                        body: body,
                        trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false),
                        reason: "temp_above_asap(bias=\(tuningBias),th=\(Int(th)))"
                    )
                }
            } else {
                results.append(.init(id: id(for: cityId), cityId: cityId, cityName: cityName, title: baseTitle, body: "", outcome: .suppressed, reason: "temp_above_condition_false(bias=\(tuningBias),th=\(Int(th)))", nextTriggerText: nil))
            }

        case .tempBelow:
            let base = Double(rule.temperature ?? 5)
            // bias=-1 => harder to trigger (need colder) / bias=+1 => easier to trigger
            let th = base + Double(tuningBias) * 2.0
            if meetsTemp(forecast, threshold: th, above: false) {
                let body = defaultBodyToday(for: forecast, cityName: cityName, locale: locale)
                if let dc = todayDateComponents(hour: rule.hour, minute: rule.minute) {
                    await addRequest(
                        identifier: id(for: cityId),
                        title: baseTitle,
                        body: body,
                        trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false),
                        reason: "temp_below(bias=\(tuningBias),th=\(Int(th)))"
                    )
                } else {
                    var cal = Calendar.current
                    cal.timeZone = .current
                    let fire = cal.date(byAdding: .minute, value: 1, to: Date()) ?? Date().addingTimeInterval(60)
                    let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    await addRequest(
                        identifier: id(for: cityId),
                        title: baseTitle,
                        body: body,
                        trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false),
                        reason: "temp_below_asap(bias=\(tuningBias),th=\(Int(th)))"
                    )
                }
            } else {
                results.append(.init(id: id(for: cityId), cityId: cityId, cityName: cityName, title: baseTitle, body: "", outcome: .suppressed, reason: "temp_below_condition_false(bias=\(tuningBias),th=\(Int(th)))", nextTriggerText: nil))
            }
        }

        return results
    }

    // MARK: Per-day (today / tomorrow) one-shot scheduling
    static func scheduleToday(for cityId: Int, cityName: String, hour: Int, minute: Int, locale: Locale, forecast: WeatherResponse?) async {
        guard let dc = todayDateComponents(hour: hour, minute: minute) else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = String(localized: .init("notification.title.today"))
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

    static func scheduleTomorrow(for cityId: Int, cityName: String, hour: Int, minute: Int, locale: Locale, forecast: WeatherResponse?) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = String(localized: .init("notification.title.tomorrow"))
        content.body = defaultBody(for: forecast, cityName: cityName, locale: locale)

        // Schedule for *today* at the specified time if possible; otherwise, schedule ASAP (next minute)
        if let dc = todayDateComponents(hour: hour, minute: minute) {
            let req = UNNotificationRequest(
                identifier: id(for: cityId) + ".tomorrow",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            )
            try? await center.add(req)
        } else {
            // The chosen time has already passed today. Schedule soon (next minute) so the user still receives it *today*.
            var cal = Calendar.current
            cal.timeZone = .current
            let fire = cal.date(byAdding: .minute, value: 1, to: Date()) ?? Date().addingTimeInterval(60)
            let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let req = UNNotificationRequest(
                identifier: id(for: cityId) + ".tomorrow",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            )
            try? await center.add(req)
        }
        #if DEBUG
        await debugDumpPending(for: cityId)
        #endif
    }

    static func cancelToday(for cityId: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id(for: cityId) + ".today"])
        center.removeDeliveredNotifications(withIdentifiers: [id(for: cityId) + ".today"])
    }

    static func cancelTomorrow(for cityId: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id(for: cityId) + ".tomorrow"])
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

    private static func previousWeekday(_ wd: Int) -> Int { wd == 1 ? 7 : (wd - 1) }

    private static func bodyContent(defaultText: String, locale: Locale) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = String(localized: .init("notification.title.reminder"))
        c.body = defaultText
        return c
    }

    /// 明日用の本文（都市名＋天気＋最高/最低）
    private static func defaultBody(for forecast: WeatherResponse?, cityName: String, locale: Locale) -> String {
        guard let d = wxDataFirst(forecast) else {
            return String(localized: .init("notification.body.reminder_default"))
        }

        // 明日は index 1、なければ index 0
        let mrf = d.mrf ?? []
        let idx = (mrf.count > 1) ? 1 : 0
        guard mrf.indices.contains(idx) else {
            return String(localized: .init("notification.body.reminder_default"))
        }

        let code = mrf[idx].wx
        let max = Double(mrf[idx].maxtemp ?? -9999)
        let min = Double(mrf[idx].mintemp ?? -9999)

        let desc = WXWeatherText.shortLabel(for: code)
        let highValue = formatTemperature(max, locale: locale)
        let lowValue  = formatTemperature(min, locale: locale)
        let high = String(format: String(localized: .init("temp.high")), locale: locale, highValue)
        let low  = String(format: String(localized: .init("temp.low")),  locale: locale, lowValue)
        return "\(cityName): \(desc) \(high) / \(low)"
    }


    /// 本日用の本文（都市名＋天気＋最高/最低）
    private static func defaultBodyToday(for forecast: WeatherResponse?, cityName: String, locale: Locale) -> String {
        guard let d = wxDataFirst(forecast) else {
            return String(localized: .init("notification.body.today_default"))
        }

        let mrf = d.mrf ?? []
        guard let today = mrf.first else {
            return String(localized: .init("notification.body.today_default"))
        }

        let code = today.wx
        let max = Double(today.maxtemp ?? -9999)
        let min = Double(today.mintemp ?? -9999)

        let desc = WXWeatherText.shortLabel(for: code)
        let highValue = formatTemperature(max, locale: locale)
        let lowValue  = formatTemperature(min, locale: locale)
        let high = String(format: String(localized: .init("temp.high")), locale: locale, highValue)
        let low  = String(format: String(localized: .init("temp.low")),  locale: locale, lowValue)
        return "\(cityName): \(desc) \(high) / \(low)"
    }


    private static func wxDataFirst(_ forecast: WeatherResponse?) -> WeatherData? {
        forecast?.wxdata?.first
    }

    /// 明日の天気コード（mrf[1] があればそれ、なければ mrf[0]）
    private static func tomorrowWxCode(_ forecast: WeatherResponse?) -> Int? {
        guard let d = wxDataFirst(forecast) else { return nil }
        let mrf = d.mrf ?? []
        let idx = (mrf.count > 1) ? 1 : 0
        guard mrf.indices.contains(idx) else { return nil }
        return mrf[idx].wx
    }

    /// 強い降水のみ（bias=-1 の時に使用）
    private static func isHeavyPrecipitation(_ wx: Int) -> Bool {
        // 大雨・嵐系、雷、暴風雨、大雪など「外出に影響が大きい」ものだけ
        switch wx {
        case 306, 308, 328, 329, 340, 350: // heavy rain / rain+storm
            return true
        case 405, 406, 407, 425, 450: // heavy snow / blizzard / thunder snow
            return true
        case 800: // thunder
            return true
        case 850...899: // storm / heavy rain-storm variants
            return true
        case 950...999: // heavy snow / no data etc (treat as heavy to avoid missing)
            return true
        default:
            // 650 は小雨なので heavy 扱いにしない
            return false
        }
    }

    private static func meetsTemp(_ forecast: WeatherResponse?, threshold: Double, above: Bool) -> Bool {
        guard let d = wxDataFirst(forecast) else { return false }
        let mrf = d.mrf ?? []
        guard let today = mrf.first else { return false }

        let max = Double(today.maxtemp ?? -9999)
        let min = Double(today.mintemp ?? -9999)

        if above {
            if max == -9999 { return false }
            return max >= threshold
        } else {
            if min == -9999 { return false }
            return min <= threshold
        }
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


private func nextTriggerText(from trigger: UNNotificationTrigger?, locale: Locale) -> String? {
        guard let trigger else { return nil }
        if let cal = trigger as? UNCalendarNotificationTrigger {
            if let next = cal.nextTriggerDate() {
                let f = DateFormatter()
                f.locale = locale
                f.dateStyle = .none
                f.timeStyle = .short
                return f.string(from: next)
            }
            let c = cal.dateComponents
            if let h = c.hour, let m = c.minute {
                return String(format: "%02d:%02d", h, m)
            }
            return nil
        }
        if let time = trigger as? UNTimeIntervalNotificationTrigger {
            let sec = Int(time.timeInterval)
            return "in \(sec)s"
        }
        return nil
    }
