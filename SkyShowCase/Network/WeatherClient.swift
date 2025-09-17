import Foundation

struct WeatherClient {
    static let shared = WeatherClient()
    private let cache = WeatherCache()

    // Search cities via Open-Meteo Geocoding
    func searchCities(query: String) async throws -> [OpenMeteoCity] {
        if let cached = await cache.city(for: query) { return cached }
        guard var comps = URLComponents(string: AppConfig().endpoint.geocodingBase) else {
            throw WeatherError.invalidURL
        }
        comps.queryItems = [
            .init(name: "name", value: query),
            .init(name: "count", value: "10"),
            .init(name: "language", value: "ja"),
            .init(name: "format", value: "json")
        ]
        guard let url = comps.url else { throw WeatherError.invalidURL }
        let geoResp: OpenMeteoGeocodingResponse = try await fetch(url, decode: OpenMeteoGeocodingResponse.self)
        guard let results = geoResp.results, !results.isEmpty else { throw WeatherError.emptyResult }
        await cache.setCity(results, for: query)
        return results
    }

    // Fetch forecast (current + daily) via Open-Meteo
    func fetchForecast(lat: Double, lon: Double) async throws -> Forecast {
        guard var comps = URLComponents(string: AppConfig().endpoint.forecastBase) else {
            throw WeatherError.invalidURL
        }
        comps.queryItems = [
            .init(name: "latitude", value: "\(lat)"),
            .init(name: "longitude", value: "\(lon)"),
            .init(name: "current_weather", value: "true"),
            .init(name: "daily", value: "weathercode,temperature_2m_max,temperature_2m_min"),
            .init(name: "timezone", value: "auto")
        ]
        guard let url = comps.url else { throw WeatherError.invalidURL }
        let resp = try await fetch(url, decode: OpenMeteoResponse.self, retries: 1)

        let current = Forecast.Current(
            temperature_2m: resp.current_weather.temperature,
            weather_code: resp.current_weather.weathercode,
            apparent_temperature: resp.current_weather.temperature,
            wind_speed_10m: resp.current_weather.windspeed,
            time: resp.current_weather.time
        )
        let daily = Forecast.Daily(
            time: resp.daily.time,
            weather_code: resp.daily.weathercode,
            temperature_2m_max: resp.daily.temperature_2m_max,
            temperature_2m_min: resp.daily.temperature_2m_min
        )
        return Forecast(current: current, daily: daily)
    }

    // Shared fetch with optional retries
    private func fetch<T: Decodable>(_ url: URL, decode: T.Type, retries: Int = 0) async throws -> T {
        var attempt = 0
        var delayNs: UInt64 = 300_000_000
        while true {
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                guard let http = resp as? HTTPURLResponse else { throw WeatherError.other(URLError(.badServerResponse)) }
                guard (200..<300).contains(http.statusCode) else { throw WeatherError.serverError(status: http.statusCode) }
                return try JSONDecoder().decode(T.self, from: data)
            } catch is CancellationError {
                throw WeatherError.cancelled
            } catch {
                if attempt < retries {
                    attempt += 1
                    try await Task.sleep(nanoseconds: delayNs)
                    delayNs *= 2
                    continue
                }
                throw (error as? WeatherError) ?? WeatherError.other(error)
            }
        }
    }
}
