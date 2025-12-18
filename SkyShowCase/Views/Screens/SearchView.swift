import SwiftUI
import Observation

struct SearchView: View {
    @Environment(AppState.self) private var state
    @State private var currentLocationCity: City?
    @State private var isFetchingLocation = false

    var body: some View {
        @Bindable var state = state
        List {
            CurrentLocationSectionView(
                currentLocationCity: $currentLocationCity,
                isFetchingLocation: $isFetchingLocation,
                fetchCurrentLocation: { await fetchCurrentLocation() }
            )
            SearchResultsSectionView()
        }
        .navigationTitle("tab.search")
        .onChange(of: state.searchText) { (_: String, new: String) in
            debounceSearch(new)
        }
        .navigationDestination(for: City.self) { city in
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
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            CustomSearchBar(text: $state.searchText, placeholder: String(localized: .init("search.prompt")))
                .padding(.horizontal)
                .padding(.top, 8)
                .background(.bar)
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
    return String(localized: .init("tab.search"))
}

private func localizedSearchResults(for locale: Locale) -> String {
    return String(localized: .init("search.results"))
}

private func localizedSearchPrompt(for locale: Locale) -> String {
    return String(localized: .init("search.prompt"))
}

private struct CustomSearchBar: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .disableAutocorrection(true)
                .autocapitalization(.none)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
