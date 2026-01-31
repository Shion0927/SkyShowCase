//
//  WXWeatherSymbols.swift
//  WeatherCue
//
//  Created by 植村詩苑 on 2025/12/23.
//

import Foundation

enum WXWeatherSymbols {
    static func symbolName(for code: Int) -> String {
        switch WXWeatherCode.kind(for: code) {
        case .clear:     return "sun.max"
        case .cloudy:    return "cloud"
        case .rain:      return "cloud.rain"
        case .snow:      return "cloud.snow"
        case .sleet:     return "cloud.sleet"
        case .thunder:   return "cloud.bolt.rain"
        case .heat:      return "thermometer.sun"
        case .storm:     return "cloud.heavyrain"
        case .heavySnow: return "snowflake"
        case .fog:       return "cloud.fog"
        case .unknown:   return "questionmark"
        }
    }
}
