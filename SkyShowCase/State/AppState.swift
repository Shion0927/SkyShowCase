import Foundation
import SwiftUI
import CoreLocation
import Observation

@MainActor
@Observable
final class AppState {
    // MARK: - Search / Forecast State
    var searchText: String = ""
    var searchResults: [City] = []
    var isSearching = false
    var isLoadingForecast = false
    var forecast: WeatherResponse?
    var currentCity: City?

    /// UI側で「選択中の都市」として参照するための名前（互換用）
    var selectedCity: City? {
        get { currentCity }
        set { currentCity = newValue }
    }
    var errorMessage: String?

    // MARK: - Compatibility (for new UI naming)
    var isFetchingForecast: Bool {
        get { isLoadingForecast }
        set { isLoadingForecast = newValue }
    }

    var forecastErrorText: String? {
        get { errorMessage }
        set { errorMessage = newValue }
    }

    // MARK: - Favorites
    private let favoritesKey = "favorites.cities"
    var favorites: [City] = []

    /// UI側の命名互換（favoriteCities）
    var favoriteCities: [City] {
        get { favorites }
        set { favorites = newValue }
    }

    // 現在地（UIが参照する）
    var currentLocationCity: City? = nil
    var locationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Dependencies
    @ObservationIgnored private let client: WeatherClient
    @ObservationIgnored private let locationHelper = LocationHelper()

    // MARK: - Init
    init(client: WeatherClient = .shared) {
        self.client = client
        // Load favorites
        loadFavorites()
        // 位置情報はUI側で明示的にrefreshを呼ぶが、状態だけ先に持っておく
        self.locationStatus = locationHelper.authorizationStatus
    }

    // MARK: - Search
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

    // MARK: - Forecast

    /// 選択都市を更新し、同時に予報も取得する（UI側はこれだけ呼べば良い）
    func selectCityAndFetch(_ city: City) async {
        selectedCity = city
        await refreshForecastForSelectedCity()
    }

    /// 現在の選択都市に対して予報を取得する（多重実行防止あり）
    func refreshForecastForSelectedCity() async {
        guard let city = selectedCity else { return }
        if isLoadingForecast { return }

        isLoadingForecast = true
        errorMessage = nil
        defer { isLoadingForecast = false }

        do {
            self.forecast = try await client.fetchForecast(lat: city.latitude, lon: city.longitude)
        } catch is CancellationError {
            self.errorMessage = WeatherError.cancelled.localizedDescription
            self.forecast = nil
        } catch {
            self.errorMessage = (error as? WeatherError)?.localizedDescription ?? error.localizedDescription
            self.forecast = nil
        }
    }

    func loadForecast(for city: City) {
        Task {
            await selectCityAndFetch(city)
        }
    }

    // MARK: - Favorites helpers
    func isFavorite(_ city: City) -> Bool {
        favorites.contains(where: { $0.id == city.id })
    }

    func toggleFavorite(_ city: City) {
        if let idx = favorites.firstIndex(where: { $0.id == city.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(city)
        }
        persistFavorites()
    }

    private func persistFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let items = try? JSONDecoder().decode([City].self, from: data) {
            self.favorites = items
        }
    }

    func saveFavorites() {
        persistFavorites()
    }

    func addFavorite(_ city: City) {
        if favorites.contains(where: { $0.id == city.id }) { return }
        favorites.insert(city, at: 0)
        persistFavorites()
    }

    func removeFavorite(id: Int) {
        favorites.removeAll { $0.id == id }
        persistFavorites()
        if currentCity?.id == id { currentCity = nil }
    }

    // MARK: - Current Location → City

    func requestLocationIfNeeded() {
        locationStatus = locationHelper.authorizationStatus
        if locationStatus == .notDetermined {
            Task {
                _ = await locationHelper.requestAuthorization()
                locationStatus = locationHelper.authorizationStatus
            }
        }
    }

    func refreshCurrentLocation() {
        Task {
            let city = await fetchCurrentLocationCity()
            self.currentLocationCity = city
            if city != nil {
                // 初回は現在地を選択状態にしても良いが、挙動はUI側で決める
            }
        }
    }

    func fetchCurrentLocationCity(
        fallbackName: String = "現在地",
        locale: Locale = .current
    ) async -> City? {
        do {
            let loc = try await locationHelper.requestOneShotLocation()
            // Reverse geocode to get human-friendly names
            let geocoder = CLGeocoder()
            let placemark: CLPlacemark? = await {
                if #available(iOS 16.0, *) {
                    return try? await geocoder.reverseGeocodeLocation(loc, preferredLocale: locale).first
                } else {
                    return try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<CLPlacemark?, Error>) in
                        geocoder.reverseGeocodeLocation(loc) { placemarks, error in
                            if let error = error {
                                cont.resume(throwing: error)
                            } else {
                                cont.resume(returning: placemarks?.first)
                            }
                        }
                    }
                }
            }()

            let name = placemark?.locality
                ?? placemark?.subLocality
                ?? placemark?.administrativeArea
                ?? placemark?.name
                ?? fallbackName

            #if swift(>=5.7)
            let countryCode: String = {
                if #available(iOS 16.0, *) { return placemark?.isoCountryCode ?? Locale.current.region?.identifier ?? "" }
                return placemark?.isoCountryCode ?? Locale.current.region?.identifier ?? ""
            }()
            #else
            let countryCode: String = placemark?.isoCountryCode ?? Locale.current.regionCode ?? ""
            #endif

            let countryName = placemark?.country ?? locale.identifier
            let admin1 = placemark?.administrativeArea

            let latKey = Int((loc.coordinate.latitude * 10_000).rounded())
            let lonKey = Int((loc.coordinate.longitude * 10_000).rounded())
            let stableId = latKey &* 100_000 + lonKey

            return City(
                id: stableId,
                name: name,
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                country: countryName,
                country_code: countryCode,
                admin1: admin1
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Location Helper (one-shot)
final class LocationHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorization() async -> CLAuthorizationStatus {
        await requestAuthorizationInternal()
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestOneShotLocation() async throws -> CLLocation {
        // Ensure services are enabled
        guard CLLocationManager.locationServicesEnabled() else { throw CLError(.locationUnknown) }

        // Authorization flow
        var status = manager.authorizationStatus
        if status == .notDetermined {
            status = await requestAuthorizationInternal()
        }
        switch status {
        case .denied, .restricted: throw CLError(.denied)
        default: break
        }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CLLocation, Error>) in
            self.locationContinuation = cont
            self.manager.requestLocation()
        }
    }

    private func requestAuthorizationInternal() async -> CLAuthorizationStatus {
        await withCheckedContinuation { (cont: CheckedContinuation<CLAuthorizationStatus, Never>) in
            self.authContinuation = cont
            self.manager.requestWhenInUseAuthorization()
        }
    }

    // MARK: CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if let cont = authContinuation {
            cont.resume(returning: manager.authorizationStatus)
            authContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.first {
            locationContinuation?.resume(returning: loc)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
