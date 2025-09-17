import Foundation

actor WeatherCache {
    private var cityResults: [String: [OpenMeteoCity]] = [:]
    private var forecastResults: [OpenMeteoCity: Forecast] = [:]

    func city(for query: String) -> [OpenMeteoCity]? {
        cityResults[query.lowercased()]
    }

    func setCity(_ cities: [OpenMeteoCity], for query: String) {
        cityResults[query.lowercased()] = cities
    }

    func forecast(for city: OpenMeteoCity) -> Forecast? {
        forecastResults[city]
    }

    func setForecast(_ f: Forecast, for city: OpenMeteoCity) {
        forecastResults[city] = f
    }
}
