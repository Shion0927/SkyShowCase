import Foundation

// MARK: - Geocoding
struct OpenMeteoGeocodingResponse: Decodable {
    let results: [OpenMeteoCity]?
}

struct OpenMeteoCity: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String
    let country_code: String
    let admin1: String?
}

// MARK: - Country helper (JP only localized)
func countryName(from code: String?) -> String? {
    guard let code = code else { return nil }
    switch code.uppercased() {
    case "JP": return "日本"
    default: return code
    }
}

// MARK: - Open-Meteo Forecast
struct OpenMeteoResponse: Decodable {
    struct CurrentWeather: Decodable {
        let temperature: Double
        let windspeed: Double
        let weathercode: Int
        let time: String
    }
    struct Daily: Decodable {
        let time: [String]
        let weathercode: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }
    let current_weather: CurrentWeather
    let daily: Daily
}

// MARK: - App Unified Model
struct Forecast: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
        let apparent_temperature: Double
        let wind_speed_10m: Double
        let time: String
    }
    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }
    let current: Current
    let daily: Daily
}
