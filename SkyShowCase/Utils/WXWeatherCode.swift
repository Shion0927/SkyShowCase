//
//  WXWeatherCode.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2025/12/23.
//

import Foundation

/// WXTech (ss1wx) weather code normalization.
///
/// Source reference: WX weather code table (Chapter 7 / 7.2) shared in this project.
/// UI should not hardcode many individual codes in each screen; use this mapper.
enum WXWeatherCode {

    /// Semantic buckets for UI/logic.
    enum Kind: String, CaseIterable {
        case clear
        case cloudy
        case rain
        case snow
        case sleet
        case thunder
        case heat
        case storm
        case heavySnow
        case fog
        case unknown
    }

    /// Returns a semantic kind for the provided WX code.
    ///
    /// Notes:
    /// - We prioritize explicit codes listed in the table (e.g. 350 thunder-rain, 430 sleet, 800 thunder, 850 storm, 950 heavy snow).
    /// - For the rest, we fall back to broad ranges (100s sunny, 200s cloudy, 300s rain, 400s snow).
    static func kind(for code: Int) -> Kind {
        if code == -9999 || code == 999 { return .unknown }

        // Explicit notable codes (from the provided mapping)
        switch code {
        case 209, 231:
            return .fog
        case 350, 800:
            return .thunder
        case 430, 329, 340, 426, 427:
            // 430 is sleet. Others are rain/snow mix & sleet variants.
            return .sleet
        case 450:
            return .thunder
        case 550, 552, 553, 558, 562, 563, 568, 572, 573, 582, 583:
            return .heat
        case 850, 851, 852, 853, 854, 855, 859, 861, 862, 863, 864, 865, 869,
             871, 872, 873, 874, 881, 882, 883, 884:
            return .storm
        case 950, 951, 952, 953, 954, 958, 961, 962, 963, 964, 968,
             971, 972, 973, 974, 981, 982, 983, 984:
            return .heavySnow
        default:
            break
        }

        // Range fallback (7.2 representative families)
        if (100...199).contains(code) { return .clear }
        if (200...299).contains(code) { return .cloudy }
        if (300...399).contains(code) { return .rain }
        if (400...499).contains(code) { return .snow }

        // 500: 快晴
        if code == 500 { return .clear }

        // 600: うすぐもり
        if code == 600 { return .cloudy }

        // 650: 小雨
        if code == 650 { return .rain }

        // 800+ already handled as thunder/storm above, but keep a safe fallback
        if (800...899).contains(code) { return .thunder }

        // 900s: treat as heavy snow family in this dataset (table includes 950+; fallback to heavySnow)
        if (900...999).contains(code) { return .heavySnow }

        return .unknown
    }

    // MARK: - Convenience predicates

    static func isClear(_ code: Int) -> Bool {
        kind(for: code) == .clear
    }

    static func isCloudy(_ code: Int) -> Bool {
        kind(for: code) == .cloudy
    }

    static func isRain(_ code: Int) -> Bool {
        switch kind(for: code) {
        case .rain, .storm, .thunder:
            return true
        default:
            return false
        }
    }

    static func isSnow(_ code: Int) -> Bool {
        switch kind(for: code) {
        case .snow, .heavySnow:
            return true
        default:
            return false
        }
    }

    static func isPrecipitation(_ code: Int) -> Bool {
        switch kind(for: code) {
        case .rain, .snow, .sleet, .storm, .heavySnow, .thunder:
            return true
        default:
            return false
        }
    }

    static func isSevere(_ code: Int) -> Bool {
        switch kind(for: code) {
        case .storm, .heavySnow, .heat, .thunder:
            return true
        default:
            return false
        }
    }

    /// Short Japanese label for UI.
    static func shortLabel(for code: Int) -> String {
        switch kind(for: code) {
        case .clear: return "晴れ"
        case .cloudy: return "くもり"
        case .rain: return "雨"
        case .snow: return "雪"
        case .sleet: return "みぞれ"
        case .thunder: return "雷"
        case .heat: return "猛暑"
        case .storm: return "大雨・嵐"
        case .heavySnow: return "大雪"
        case .fog: return "霧"
        case .unknown: return "--"
        }
    }
}
