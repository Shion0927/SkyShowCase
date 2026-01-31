//
//  NotificationLog.swift
//  WeatherCue
//
//  Created by 植村詩苑 on 2026/01/31.
//


//
//  NotificationLog.swift
//  WeatherCue
//
//  Created by 植村詩苑 on 2026/01/31.
//

import Foundation

/// NotificationScheduler が返す ScheduleResult を永続化して、通知履歴として表示するためのストア。
/// まずは安全に UserDefaults(JSON) に保存する。
///
/// - 目的: scheduled / suppressed / failed の理由を残して「なぜ？」が追えるようにする（C）。
/// - 将来: 容量/検索が必要ならファイル保存やDBへ移行。

enum NotificationLogStore {

    // MARK: - Storage

    private static let storageKey = "notification.log.items.v1"
    private static let maxItems: Int = 200

    // MARK: - Public API

    /// 全件取得（新しい順）
    static func load() -> [NotificationScheduler.ScheduleResult] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        do {
            let items = try JSONDecoder().decode([NotificationScheduler.ScheduleResult].self, from: data)
            return items.sorted { $0.createdAt > $1.createdAt }
        } catch {
            // フォーマット変更や破損時は破棄して復旧
            UserDefaults.standard.removeObject(forKey: storageKey)
            return []
        }
    }

    /// 追記（結果配列をそのまま保存）
    static func append(_ results: [NotificationScheduler.ScheduleResult]) {
        guard !results.isEmpty else { return }
        var current = load()
        current.append(contentsOf: results)
        // createdAt 降順に整列して上限で切る
        current.sort { $0.createdAt > $1.createdAt }
        if current.count > maxItems {
            current = Array(current.prefix(maxItems))
        }
        save(current)
    }

    /// 1件だけ追記
    static func append(_ result: NotificationScheduler.ScheduleResult) {
        append([result])
    }

    /// 全削除
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Helpers

    private static func save(_ items: [NotificationScheduler.ScheduleResult]) {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // encode に失敗することは基本ないが、安全のため保存を諦める
#if DEBUG
            print("[NotificationLogStore] ❌ Encode failed: \(error)")
#endif
        }
    }
}
