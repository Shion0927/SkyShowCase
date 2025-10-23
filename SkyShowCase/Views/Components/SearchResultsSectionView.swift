import SwiftUI

struct SearchResultsSectionView: View {
    @Environment(\.appConfig) private var config
    @Environment(AppState.self) private var state

    var body: some View {
        if !state.searchResults.isEmpty {
            Section(String(localized: .init("search.results"))) {
                ForEach(state.searchResults) { city in
                    NavigationLink(value: city) {
                        CityRow(city: city)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if state.isFavorite(city) {
                            Button(role: .destructive) { state.toggleFavorite(city) } label: {
                                Label(String(localized: .init("favorites.remove")), systemImage: "star.slash")
                            }
                        } else {
                            Button { state.toggleFavorite(city) } label: {
                                Label(String(localized: .init("favorites.add")), systemImage: "star")
                            }
                        }
                    }
                }
            }
        }
    }
}
