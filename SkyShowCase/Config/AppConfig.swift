import SwiftUI

// MARK: - App Configuration & Environment
struct AppConfig {
    var temperatureUnit: UnitTemperature = .celsius
    var primaryTint: Color = .blue
    var locale: Locale = .current
    var endpoint = Endpoint()
    /// Weathernews WXTech API key (ss1wx). Set via environment or replace with your secure storage.
    var apiKey: String = "kKmcTu2Rc6a16T4juPzMKa6wDx0tuJIC7RRfG8bZ"

    struct Endpoint {
        // Geocoding: Open-Meteo (temporary, can be swapped later)
        let geocodingBase = "https://geocoding-api.open-meteo.com/v1/search"
        // Forecast: Weathernews WXTech (ss1wx)
        let wxtechForecastBase = "https://wxtech.weathernews.com/api/v1/ss1wx"
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
