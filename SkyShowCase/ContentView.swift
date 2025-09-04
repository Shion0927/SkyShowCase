import SwiftUI
import Observation

// MARK: - Environment

struct AppConfig {
    var temperatureUnit: UnitTemperature = .celsius
    var primaryTint: Color = .blue
    var endpoint = Endpoint()
    // ★ OpenWeatherMap APIキー（ここをあなたのキーに差し替え）
    var openWeatherAPIKey: String = "YOUR_OWM_API_KEY"

    struct Endpoint {
        // OpenWeatherMap
        let geocodingBase = "https://api.openweathermap.org/geo/1.0/direct"
        let forecastBase  = "https://api.openweathermap.org/data/3.0/onecall"
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

// MARK: - Networking / Cache

enum WeatherError: LocalizedError {
    case invalidURL
    case decodingFailed
    case serverError(status: Int)
    case emptyResult
    case cancelled
    case other(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "不正なURLです。"
        case .decodingFailed: return "データの解析に失敗しました。"
        case .serverError(let s): return "サーバーエラー（\(s)）。"
        case .emptyResult: return "該当する結果がありません。"
        case .cancelled: return "リクエストはキャンセルされました。"
        case .other(let e): return e.localizedDescription
        }
    }
}

actor WeatherCache {
    private var cityResults: [String: [City]] = [:]
    private var forecastResults: [String: Forecast] = [:]
    
    func city(for query: String) -> [City]? { cityResults[query.lowercased()] }
    func setCity(_ cities: [City], for query: String) { cityResults[query.lowercased()] = cities }
    
    func forecast(lat: Double, lon: Double) -> Forecast? {
        forecastResults["\(lat),\(lon)"]
    }
    func setForecast(_ f: Forecast, lat: Double, lon: Double) {
        forecastResults["\(lat),\(lon)"] = f
    }
}

@MainActor
@Observable
final class AppState {
    var searchText: String = ""
    var searchResults: [City] = []
    var isSearching = false
    var isLoadingForecast = false
    var forecast: Forecast?
    var currentCity: City?
    var errorMessage: String?
    
    init(client: WeatherClient = .shared) {
        self.client = client
    }
    private let client: WeatherClient
    
    func searchCities(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.searchResults = []
            return
        }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                self.searchResults = try await client.searchCities(query: query)
            } catch is CancellationError {
                self.errorMessage = WeatherError.cancelled.localizedDescription
            } catch {
                self.errorMessage = (error as? WeatherError)?.localizedDescription ?? error.localizedDescription
            }
            isSearching = false
        }
    }
    
    func loadForecast(for city: City) {
        isLoadingForecast = true
        errorMessage = nil
        currentCity = city
        Task {
            do {
                self.forecast = try await client.fetchForecast(lat: city.latitude, lon: city.longitude)
            } catch is CancellationError {
                self.errorMessage = WeatherError.cancelled.localizedDescription
            } catch {
                self.errorMessage = (error as? WeatherError)?.localizedDescription ?? error.localizedDescription
            }
            isLoadingForecast = false
        }
    }
}

struct WeatherClient {
    static let shared = WeatherClient()
    private let cache = WeatherCache()
    
    // 検索（都市）: OpenWeatherMap Direct Geocoding
    func searchCities(query: String) async throws -> [City] {
        if let cached = await cache.city(for: query) { return cached }
        guard var comps = URLComponents(string: AppConfig().endpoint.geocodingBase) else {
            throw WeatherError.invalidURL
        }
        let apiKey = AppConfig().openWeatherAPIKey
        comps.queryItems = [
            .init(name: "q", value: query),
            .init(name: "limit", value: "10"),
            .init(name: "appid", value: apiKey),
            .init(name: "lang", value: "ja")
        ]
        guard let url = comps.url else { throw WeatherError.invalidURL }
        let owmCities: [OWMDirectCity] = try await fetch(url, decode: [OWMDirectCity].self)
        let cities: [City] = owmCities.map {
            City(name: $0.name, country: $0.country, latitude: $0.lat, longitude: $0.lon, admin1: $0.state)
        }
        guard !cities.isEmpty else { throw WeatherError.emptyResult }
        await cache.setCity(cities, for: query)
        return cities
    }
    
    // 予報（現在＋7日）: OpenWeatherMap One Call 3.0
    func fetchForecast(lat: Double, lon: Double) async throws -> Forecast {
        if let cached = await cache.forecast(lat: lat, lon: lon) { return cached }
        guard var comps = URLComponents(string: AppConfig().endpoint.forecastBase) else {
            throw WeatherError.invalidURL
        }
        let apiKey = AppConfig().openWeatherAPIKey
        comps.queryItems = [
            .init(name: "lat", value: "\(lat)"),
            .init(name: "lon", value: "\(lon)"),
            .init(name: "exclude", value: "minutely,hourly,alerts"),
            .init(name: "units", value: "metric"),
            .init(name: "lang", value: "ja"),
            .init(name: "appid", value: apiKey)
        ]
        guard let url = comps.url else { throw WeatherError.invalidURL }
        let owm = try await fetch(url, decode: OWMForecast.self, retries: 2)

        // OWM → 既存 Forecast へアダプト
        func isoString(from epoch: TimeInterval) -> String {
            let d = Date(timeIntervalSince1970: epoch)
            let f = ISO8601DateFormatter()
            return f.string(from: d)
        }
        func ymd(from epoch: TimeInterval) -> String {
            let d = Date(timeIntervalSince1970: epoch)
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = .en_US_POSIX
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: d)
        }

        let curr = Forecast.Current(
            temperature_2m: owm.current.temp,
            weather_code: owm.current.weather.first?.id ?? -1, // OWM weather.id
            apparent_temperature: owm.current.feels_like,
            wind_speed_10m: owm.current.wind_speed,
            time: isoString(from: owm.current.dt)
        )

        var times: [String] = []
        var codes: [Int] = []
        var tmax: [Double] = []
        var tmin: [Double] = []
        for d in owm.daily.prefix(7) {
            times.append(ymd(from: d.dt))
            codes.append(d.weather.first?.id ?? -1)
            tmax.append(d.temp.max)
            tmin.append(d.temp.min)
        }
        let daily = Forecast.Daily(
            time: times,
            weather_code: codes,
            temperature_2m_max: tmax,
            temperature_2m_min: tmin
        )
        let forecast = Forecast(current: curr, daily: daily)
        await cache.setForecast(forecast, lat: lat, lon: lon)
        return forecast
    }
    
    // 共通fetch（指数バックオフつき）
    private func fetch<T: Decodable>(_ url: URL, decode: T.Type, retries: Int = 0) async throws -> T {
        var attempt = 0
        var delayNs: UInt64 = 300_000_000 // 0.3s
        while true {
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 15
                let (data, resp) = try await URLSession.shared.data(for: req)
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

// MARK: - Models

// 都市モデル（アプリ内で使用）
struct City: Decodable, Identifiable, Hashable {
    var id: String { "\(name)-\(latitude)-\(longitude)" }
    let name: String
    let country: String?
    let latitude: Double
    let longitude: Double
    let admin1: String?
}

// OpenWeatherMap: Direct Geocoding レスポンスの最小モデル
struct OWMDirectCity: Decodable {
    let name: String
    let country: String?
    let state: String?
    let lat: Double
    let lon: Double
}

// OpenWeatherMap: One Call 3.0 の最小モデル
struct OWMForecast: Decodable {
    struct W: Decodable { let id: Int }
    struct Current: Decodable {
        let temp: Double
        let feels_like: Double
        let wind_speed: Double
        let dt: TimeInterval
        let weather: [W]
    }
    struct Temp: Decodable { let min: Double; let max: Double }
    struct Daily: Decodable {
        let dt: TimeInterval
        let temp: Temp
        let weather: [W]
    }
    let current: Current
    let daily: [Daily]
}

// 既存UIが使う統一モデル
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

// MARK: - Views

struct ContentView: View {
    @State private var config = AppConfig() // Environmentに流す可変設定
    
    var body: some View {
        NavigationStack {
            SearchView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("温度単位", selection: $config.temperatureUnit) {
                                Text("摂氏 (°C)").tag(UnitTemperature.celsius)
                                Text("華氏 (°F)").tag(UnitTemperature.fahrenheit)
                            }
                            Picker("テーマ", selection: Binding(
                                get: { config.primaryTint == .blue ? 0 : 1 },
                                set: { config.primaryTint = ($0 == 0 ? .blue : .orange) }
                            )) {
                                Text("ブルー").tag(0)
                                Text("オレンジ").tag(1)
                            }
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
        .tint(config.primaryTint)
        .environment(\.appConfig, config) // ← カスタムEnvironment注入
    }
}

struct SearchView: View {
    @Environment(\.appConfig) private var config
    @State private var state = AppState()
    
    var body: some View {
        List {
            Section {
                HStack {
                    TextField("都市名を検索（例: Tokyo）", text: $state.searchText)
                        .textInputAutocapitalization(.never)
                        .onSubmit { state.searchCities(state.searchText) }
                    if state.isSearching {
                        ProgressView()
                    } else if !state.searchText.isEmpty {
                        Button {
                            state.searchText = ""
                            state.searchResults = []
                        } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !state.searchResults.isEmpty {
                Section("検索結果") {
                    ForEach(state.searchResults) { city in
                        NavigationLink(value: city) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(city.name)
                                    .font(.headline)
                                Text("\(city.admin1 ?? "") \(city.country ?? "")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("SkyShowcase")
        .searchable(text: $state.searchText, prompt: "都市名")
        .onChange(of: state.searchText) { _, new in
            // タイピング抑制の簡易デバウンス
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if new == state.searchText { state.searchCities(new) }
            }
        }
        .navigationDestination(for: City.self) { city in
            ForecastView(city: city, state: state)
        }
        .alert("エラー", isPresented: .constant(state.errorMessage != nil), actions: {
            Button("OK") { state.errorMessage = nil }
        }, message: { Text(state.errorMessage ?? "") })
        .toolbarTitleMenu {
            Text("単位: \(config.temperatureUnit == .celsius ? "°C" : "°F")")
            Text("テーマ: \(config.primaryTint == .blue ? "ブルー" : "オレンジ")")
        }
    }
}

struct ForecastView: View {
    @Environment(\.appConfig) private var config
    let city: City
    @State var state: AppState
    
    var body: some View {
        List {
            if let f = state.forecast {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: symbol(for: f.current.weather_code))
                            .font(.system(size: 44))
                        VStack(alignment: .leading) {
                            Text("\(formatTemp(f.current.temperature_2m))")
                                .font(.system(size: 38, weight: .bold))
                            Text("体感 \(formatTemp(f.current.apparent_temperature)) / 風 \(Int(f.current.wind_speed_10m)) m/s")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                
                Section("7日予報") {
                    ForEach(0..<min(f.daily.time.count, 7), id: \.self) { i in
                        HStack {
                            Text(shortDate(f.daily.time[i]))
                            Spacer()
                            Image(systemName: symbol(for: f.daily.weather_code[i]))
                            Text("\(formatTemp(f.daily.temperature_2m_min[i])) - \(formatTemp(f.daily.temperature_2m_max[i]))")
                                .monospacedDigit()
                        }
                    }
                }
            } else if state.isLoadingForecast {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
            } else {
                Section { Text("予報がありません。下へ引っ張って更新してください。").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(city.name)
        .task { state.loadForecast(for: city) }
        .refreshable { state.loadForecast(for: city) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    state.loadForecast(for: city)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .alert("エラー", isPresented: .constant(state.errorMessage != nil), actions: {
            Button("再試行") { state.loadForecast(for: city) }
            Button("閉じる", role: .cancel) { state.errorMessage = nil }
        }, message: { Text(state.errorMessage ?? "") })
    }
    
    // Helpers
    func formatTemp(_ celsius: Double) -> String {
        switch config.temperatureUnit {
        case .celsius:
            return String(format: "%.1f℃", celsius)
        default:
            let f = Measurement(value: celsius, unit: UnitTemperature.celsius)
                .converted(to: .fahrenheit).value
            return String(format: "%.1f℉", f)
        }
    }
    // OWMでは daily.dt を "yyyy-MM-dd" に変換しているため両対応にしておく
    func shortDate(_ iso: String) -> String {
        let isoF = ISO8601DateFormatter()
        if let d = isoF.date(from: iso) {
            let f = DateFormatter()
            f.locale = .current
            f.setLocalizedDateFormatFromTemplate("MMMdEEE")
            return f.string(from: d)
        }
        let f2 = DateFormatter()
        f2.calendar = Calendar(identifier: .gregorian)
        f2.locale = .en_US_POSIX
        f2.dateFormat = "yyyy-MM-dd"
        if let d2 = f2.date(from: iso) {
            let out = DateFormatter()
            out.locale = .current
            out.setLocalizedDateFormatFromTemplate("MMMdEEE")
            return out.string(from: d2)
        }
        return iso
    }
    func symbol(for code: Int) -> String {
        // OpenWeatherMap weather id に基づく簡易マッピング
        switch code {
        case 200...232: return "cloud.bolt.rain.fill"   // 雷雨
        case 300...321: return "cloud.drizzle.fill"     // 霧雨
        case 500...504: return "cloud.rain.fill"        // 雨
        case 511:       return "cloud.snow.fill"        // 着氷性の雨→雪アイコンで代替
        case 520...531: return "cloud.heavyrain.fill"   // 強い雨
        case 600...622: return "cloud.snow.fill"        // 雪
        case 701...781: return "cloud.fog.fill"         // 霧・煙霧など
        case 800:       return "sun.max.fill"           // 快晴
        case 801...804: return "cloud.sun.fill"         // 雲
        default:        return "cloud.fill"
        }
    }
}
