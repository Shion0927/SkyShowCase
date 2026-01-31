import Foundation

actor WeatherCache {
    private var cityResults: [String: [City]] = [:]
    private var forecastResults: [City: WeatherForecast] = [:]

    func city(for query: String) -> [City]? {
        cityResults[query.lowercased()]
    }

    func setCity(_ cities: [City], for query: String) {
        cityResults[query.lowercased()] = cities
    }

    func forecast(for city: City) -> WeatherForecast? {
        forecastResults[city]
    }

    func setForecast(_ f: WeatherForecast, for city: City) {
        forecastResults[city] = f
    }
}

// MARK: - App Models

// A generic location model (legacy name kept to avoid large refactors)
struct City: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String
    let country_code: String
    let admin1: String?

    init(
        id: Int,
        name: String,
        latitude: Double,
        longitude: Double,
        country: String = "",
        country_code: String = "",
        admin1: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.country_code = country_code
        self.admin1 = admin1
    }
}

// Unified forecast model used by UI (legacy structure preserved)
struct WeatherForecast: Codable, Hashable {
    struct Current: Codable, Hashable {
        let temperature_2m: Double
        let weather_code: Int
        let apparent_temperature: Double
        let wind_speed_10m: Double
        let time: String
    }

    struct Daily: Codable, Hashable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }

    let current: Current
    let daily: Daily
}
