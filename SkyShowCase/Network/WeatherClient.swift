import Foundation

private struct GeocodingResponse: Decodable {
    let results: [City]?
}

struct WeatherClient {
    static let shared = WeatherClient()
    private let cache = WeatherCache()

    // Search cities via geocoding (currently Open-Meteo Geocoding)
    func searchCities(query: String) async throws -> [City] {
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
        let geoResp: GeocodingResponse = try await fetch(url, decode: GeocodingResponse.self)
        guard let results = geoResp.results, !results.isEmpty else { throw WeatherError.emptyResult }
        await cache.setCity(results, for: query)
        return results
    }

    // Fetch forecast (current + daily) via Weathernews WXTech (ss1wx)
    func fetchForecast(lat: Double, lon: Double) async throws -> WeatherResponse {
        // WXTech ss1wx endpoint
        guard var comps = URLComponents(string: AppConfig().endpoint.wxtechForecastBase) else {
            throw WeatherError.invalidURL
        }
        comps.queryItems = [
            .init(name: "lat", value: "\(lat)"),
            .init(name: "lon", value: "\(lon)")
        ]
        guard let url = comps.url else { throw WeatherError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // API key is required by WXTech
        request.setValue(AppConfig().apiKey, forHTTPHeaderField: "X-API-Key")

        let resp = try await fetch(request, decode: WeatherResponse.self, retries: 1)

        if let errs = resp.errors, !errs.isEmpty {
            let joined = errs.map { "\($0.code): \($0.message)" }.joined(separator: " / ")
            throw WeatherError.other(NSError(domain: "WXTech", code: -1, userInfo: [NSLocalizedDescriptionKey: joined]))
        }
        guard (resp.wxdata?.first) != nil else {
            throw WeatherError.emptyResult
        }

        return resp
    }

    // Shared fetch for URLRequest (allows headers) with optional retries
    private func fetch<T: Decodable>(_ request: URLRequest, decode: T.Type, retries: Int = 0) async throws -> T {
        var attempt = 0
        var delayNs: UInt64 = 300_000_000
        while true {
            do {
#if DEBUG
                print("[WeatherClient] ▶︎ Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "<nil>")")
                if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                    print("[WeatherClient] ▶︎ Headers: \(headers)")
                }
#endif
                let (data, resp) = try await URLSession.shared.data(for: request)
#if DEBUG
                if let http = resp as? HTTPURLResponse {
                    print("[WeatherClient] ◀︎ Response: status=\(http.statusCode) url=\(http.url?.absoluteString ?? "<nil>")")
                    print("[WeatherClient] ◀︎ ResponseHeaders: \(http.allHeaderFields)")
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[WeatherClient] ◀︎ Body: \n\(jsonString)")
                } else {
                    print("[WeatherClient] ◀︎ Body: <non-utf8 data, \(data.count) bytes>")
                }
#endif
                guard let http = resp as? HTTPURLResponse else { throw WeatherError.other(URLError(.badServerResponse)) }
                guard (200..<300).contains(http.statusCode) else { throw WeatherError.serverError(status: http.statusCode) }
#if DEBUG
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    return decoded
                } catch {
                    print("[WeatherClient] ❌ Decode error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("[WeatherClient] ❌ Failed body: \n\(jsonString)")
                    } else {
                        print("[WeatherClient] ❌ Failed body: <non-utf8 data, \(data.count) bytes>")
                    }
                    throw error
                }
#else
                return try JSONDecoder().decode(T.self, from: data)
#endif
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

    // Shared fetch with optional retries
    private func fetch<T: Decodable>(_ url: URL, decode: T.Type, retries: Int = 0) async throws -> T {
        var attempt = 0
        var delayNs: UInt64 = 300_000_000
        while true {
            do {
#if DEBUG
                print("[WeatherClient] ▶︎ Request: GET \(url.absoluteString)")
#endif
                let (data, resp) = try await URLSession.shared.data(from: url)
#if DEBUG
                if let http = resp as? HTTPURLResponse {
                    print("[WeatherClient] ◀︎ Response: status=\(http.statusCode) url=\(http.url?.absoluteString ?? url.absoluteString)")
                    print("[WeatherClient] ◀︎ ResponseHeaders: \(http.allHeaderFields)")
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[WeatherClient] ◀︎ Body: \n\(jsonString)")
                } else {
                    print("[WeatherClient] ◀︎ Body: <non-utf8 data, \(data.count) bytes>")
                }
#endif
                guard let http = resp as? HTTPURLResponse else { throw WeatherError.other(URLError(.badServerResponse)) }
                guard (200..<300).contains(http.statusCode) else { throw WeatherError.serverError(status: http.statusCode) }
#if DEBUG
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    return decoded
                } catch {
                    print("[WeatherClient] ❌ Decode error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("[WeatherClient] ❌ Failed body: \n\(jsonString)")
                    } else {
                        print("[WeatherClient] ❌ Failed body: <non-utf8 data, \(data.count) bytes>")
                    }
                    throw error
                }
#else
                return try JSONDecoder().decode(T.self, from: data)
#endif
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
