import Foundation
import SwiftUI
import CoreLocation

@MainActor
final class AppState: ObservableObject {
    // MARK: - Search / Forecast State
    @Published var searchText: String = ""
    @Published var searchResults: [OpenMeteoCity] = []
    @Published var isSearching = false
    @Published var isLoadingForecast = false
    @Published var forecast: Forecast?
    @Published var currentCity: OpenMeteoCity?
    @Published var errorMessage: String?

    // MARK: - Favorites
    private let favoritesKey = "favorites.cities"
    @Published var favorites: [OpenMeteoCity] = []

    // MARK: - Dependencies
    init(client: WeatherClient = .shared) {
        self.client = client
        // Load favorites
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let items = try? JSONDecoder().decode([OpenMeteoCity].self, from: data) {
            self.favorites = items
        }
    }
    private let client: WeatherClient

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
    func loadForecast(for city: OpenMeteoCity) {
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

    // MARK: - Favorites helpers
    func isFavorite(_ city: OpenMeteoCity) -> Bool {
        favorites.contains(where: { $0.id == city.id })
    }

    func toggleFavorite(_ city: OpenMeteoCity) {
        if let idx = favorites.firstIndex(where: { $0.id == city.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(city)
        }
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    // MARK: - Current Location → City
    private let locationHelper = LocationHelper()

    func fetchCurrentLocationCity(fallbackName: String = "現在地", locale: Locale = .current) async -> OpenMeteoCity? {
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
                return placemark?.isoCountryCode ?? Locale.current.regionCode ?? ""
            }()
            #else
            let countryCode: String = placemark?.isoCountryCode ?? Locale.current.regionCode ?? ""
            #endif

            let countryName = placemark?.country ?? locale.identifier
            let admin1 = placemark?.administrativeArea

            return OpenMeteoCity(
                id: -1,
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
            status = await requestAuthorization()
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

    private func requestAuthorization() async -> CLAuthorizationStatus {
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
