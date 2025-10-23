// Utils/LocaleHelpers.swift
import Foundation

enum TemperatureUnitPref: String {
    case system
    case celsius
    case fahrenheit
}

@inline(__always)
func resolvedUnitPref() -> TemperatureUnitPref {
    if let prefString = UserDefaults.standard.string(forKey: "temperatureUnitPref"),
       let pref = TemperatureUnitPref(rawValue: prefString) {
        return pref
    }
    return .system
}

@inline(__always)
func shouldUseFahrenheit(_ locale: Locale) -> Bool {
    switch resolvedUnitPref() {
    case .celsius:
        return false
    case .fahrenheit:
        return true
    case .system:
        if #available(iOS 16.0, *) {
            return locale.measurementSystem == .us
        } else {
            let fRegions: Set<String> = ["US", "BS", "BZ", "KY", "PW"]
            if let region = locale.region?.identifier ?? locale.regionCode, fRegions.contains(region) {
                return true
            }
            if let code = locale.languageCode, code == "en", locale.identifier.contains("_US") {
                return true
            }
            return false
        }
    }
}
