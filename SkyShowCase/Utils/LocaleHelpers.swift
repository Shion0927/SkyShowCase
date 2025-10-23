// Utils/LocaleHelpers.swift
import Foundation

/// 摂氏ではなく華氏を使うべき地域かどうかを判定
/// - Regions that commonly use Fahrenheit: US, Bahamas, Belize, Cayman Islands, Palau
@inline(__always)
func shouldUseFahrenheit(_ locale: Locale) -> Bool {
    let fRegions: Set<String> = ["US", "BS", "BZ", "KY", "PW"]

    if #available(iOS 16.0, *) {
        if let region = locale.region?.identifier, fRegions.contains(region) { return true }
    } else {
        if let region = locale.regionCode, fRegions.contains(region) { return true }
    }

    // Fallback: 英語US表記の明示
    if #available(iOS 16.0, *) {
        if let code = locale.language.languageCode?.identifier, code == "en",
           (locale.identifier.contains("_US") || locale.identifier.contains("-US")) {
            return true
        }
    } else {
        if let code = locale.languageCode, code == "en",
           locale.identifier.contains("_US") {
            return true
        }
    }
    return false
}
