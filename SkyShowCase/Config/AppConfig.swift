import SwiftUI

// MARK: - App Configuration & Environment
struct AppConfig {
    var temperatureUnit: UnitTemperature = .celsius
    var primaryTint: Color = .blue
    var locale: Locale = .current
    var endpoint = Endpoint()

    struct Endpoint {
        // Open-Meteo Geocoding & Forecast
        let geocodingBase = "https://geocoding-api.open-meteo.com/v1/search"
        let forecastBase  = "https://api.open-meteo.com/v1/forecast"
    }
}

private struct AppConfigKey: EnvironmentKey {
    static let defaultValue = AppConfig()
}

extension EnvironmentValues {
    var appConfig: AppConfig {
        get { self[AppConfigKey.self] }
        set { self[AppConfigKey.self] = newValue }
    }
}
