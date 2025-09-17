import SwiftUI

struct SearchView: View {
    @Environment(\.appConfig) private var config
    @EnvironmentObject private var state: AppState
    @State private var currentLocationCity: OpenMeteoCity?
    @State private var isFetchingLocation = false

    var body: some View {
        List {
            CurrentLocationSectionView(
                currentLocationCity: $currentLocationCity,
                isFetchingLocation: $isFetchingLocation,
                fetchCurrentLocation: { await fetchCurrentLocation() }
            )
            SearchResultsSectionView()
        }
        .navigationTitle(localizedTitle(for: config.locale))
        .searchable(text: $state.searchText, prompt: localizedSearchPrompt(for: config.locale))
        .onChange(of: state.searchText) { (_: String, new: String) in
            debounceSearch(new)
        }
        .navigationDestination(for: OpenMeteoCity.self) { city in
            ForecastView(city: city)
        }
        .task {
            if currentLocationCity == nil && !isFetchingLocation {
                await fetchCurrentLocation()
            }
        }
        .toolbar {
            if state.isSearching {
                ToolbarItem(placement: .topBarTrailing) { ProgressView() }
            }
        }
    }

    private func fetchCurrentLocation() async {
        isFetchingLocation = true
        defer { isFetchingLocation = false }
        if let city = await state.fetchCurrentLocationCity() {
            currentLocationCity = city
        }
    }

    private func debounceSearch(_ text: String) {
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if text == state.searchText { state.searchCities(text) }
        }
    }
}

func locationSubtitle(admin1: String?, countryCode: String) -> String {
    let parts: [String] = [admin1, countryName(from: countryCode)].compactMap { $0 }
    return parts.joined(separator: " ")
}

private func localizedTitle(for locale: Locale) -> String {
    return isJapanese(locale) ? "SkyShowcase" : "SkyShowcase"
}

private func localizedSearchResults(for locale: Locale) -> String {
    return isJapanese(locale) ? "検索結果" : "Results"
}

private func localizedSearchPrompt(for locale: Locale) -> String {
    return isJapanese(locale) ? "都市名" : "City"
}
