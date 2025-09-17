// Utils/WeatherSymbols.swift
import Foundation

/// Open-Meteo の WMO weather code を SF Symbols 名に変換
/// 参考: https://open-meteo.com/en/docs
@inline(__always)
func weatherSymbol(for code: Int) -> String {
    switch code {
    case 0:                      // Clear sky
        return "sun.max.fill"
    case 1...3:                  // Mainly clear, partly cloudy, overcast
        return "cloud.sun.fill"
    case 45, 48:                 // Fog, depositing rime fog
        return "cloud.fog.fill"
    case 51...67:                // Drizzle / Freezing drizzle
        return "cloud.drizzle.fill"
    case 71...77, 85, 86:        // Snow fall, snow grains / Snow showers
        return "cloud.snow.fill"
    case 80...82:                // Rain showers
        return "cloud.heavyrain.fill"
    case 95...99:                // Thunderstorm
        return "cloud.bolt.rain.fill"
    default:                     // Other
        return "cloud.fill"
    }
}
