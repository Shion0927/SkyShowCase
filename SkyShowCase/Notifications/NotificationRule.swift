// Notifications/NotificationRule.swift
import Foundation

/// 天気通知の条件を表すモデル（永続化対応）
struct NotificationRule: Codable, Equatable {
    /// 繰り返しタイプ
    enum Frequency: String, Codable, CaseIterable {
        /// 1回だけ
        case oneTime
        /// 毎日
        case daily
        /// 毎週（複数曜日に対応）
        case weekly
        /// 「次の雨の日」だけ
        case nextDayRain
        /// 指定温度以上の日だけ（℃ベース）
        case tempAbove
        /// 指定温度以下の日だけ（℃ベース）
        case tempBelow
    }

    /// 繰り返しタイプ
    var frequency: Frequency
    /// 毎週のときに鳴らす曜日（1=日曜 ... 7=土曜）。daily/oneTime などでは `nil`
    var weekdays: Set<Int>?
    /// 通知時刻（時）
    var hour: Int
    /// 通知時刻（分）
    var minute: Int
    /// 温度条件のしきい値（℃）。frequency が tempAbove / tempBelow のときに使用
    var temperature: Double?

    // --- Per-day toggles & times ---
    /// 本日の通知オン/オフ
    var enableToday: Bool = false
    /// 本日の通知時刻（時）
    var todayHour: Int = 9
    /// 本日の通知時刻（分）
    var todayMinute: Int = 0

    /// 明日の通知オン/オフ
    var enableTomorrow: Bool = false
    /// 明日の通知時刻（時）
    var tomorrowHour: Int = 9
    /// 明日の通知時刻（分）
    var tomorrowMinute: Int = 0

    private enum CodingKeys: String, CodingKey {
        case frequency, weekdays, hour, minute, temperature,
             enableToday, todayHour, todayMinute,
             enableTomorrow, tomorrowHour, tomorrowMinute
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try c.decode(Frequency.self, forKey: .frequency)
        weekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .weekdays)
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        temperature = try c.decodeIfPresent(Double.self, forKey: .temperature)
        // Per-day toggles: default values when missing
        enableToday = try c.decodeIfPresent(Bool.self, forKey: .enableToday) ?? false
        todayHour = try c.decodeIfPresent(Int.self, forKey: .todayHour) ?? 9
        todayMinute = try c.decodeIfPresent(Int.self, forKey: .todayMinute) ?? 0
        enableTomorrow = try c.decodeIfPresent(Bool.self, forKey: .enableTomorrow) ?? false
        tomorrowHour = try c.decodeIfPresent(Int.self, forKey: .tomorrowHour) ?? 9
        tomorrowMinute = try c.decodeIfPresent(Int.self, forKey: .tomorrowMinute) ?? 0
    }

    /// 明示的なメンバワイズ初期化子（Decodable用の init(from:) を定義したため）
    init(
        frequency: Frequency,
        weekdays: Set<Int>?,
        hour: Int,
        minute: Int,
        temperature: Double?,
        enableToday: Bool = false,
        todayHour: Int = 9,
        todayMinute: Int = 0,
        enableTomorrow: Bool = false,
        tomorrowHour: Int = 9,
        tomorrowMinute: Int = 0
    ) {
        self.frequency = frequency
        self.weekdays = weekdays
        self.hour = hour
        self.minute = minute
        self.temperature = temperature
        self.enableToday = enableToday
        self.todayHour = todayHour
        self.todayMinute = todayMinute
        self.enableTomorrow = enableTomorrow
        self.tomorrowHour = tomorrowHour
        self.tomorrowMinute = tomorrowMinute
    }

    /// デフォルトルール（毎日20:00）
    static var defaultRule: NotificationRule {
        NotificationRule(
            frequency: .daily,
            weekdays: nil,
            hour: 20,
            minute: 0,
            temperature: nil
        )
    }
}

// MARK: - 永続化（UserDefaults）

extension NotificationRule {
    /// 都市IDごとに保存するキー
    private static func key(for cityId: Int) -> String { "notify.rule.\(cityId)" }

    /// ルールを読み込み
    static func load(for cityId: Int) -> NotificationRule? {
        let key = key(for: cityId)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NotificationRule.self, from: data)
    }

    /// ルールを保存
    static func save(_ rule: NotificationRule, for cityId: Int) {
        let key = key(for: cityId)
        if let data = try? JSONEncoder().encode(rule) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
