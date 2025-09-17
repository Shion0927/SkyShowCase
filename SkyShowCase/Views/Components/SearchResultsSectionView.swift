import SwiftUI

struct SearchResultsSectionView: View {
    @Environment(\.appConfig) private var config
    @EnvironmentObject private var state: AppState

    var body: some View {
        let isJP = isJapanese(config.locale)
        if !state.searchResults.isEmpty {
            Section(isJP ? "検索結果" : "Results") {
                ForEach(state.searchResults) { city in
                    NavigationLink(value: city) {
                        CityRow(city: city)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if state.isFavorite(city) {
                            Button(role: .destructive) { state.toggleFavorite(city) } label: {
                                Label(isJP ? "削除" : "Remove", systemImage: "star.slash")
                            }
                        } else {
                            Button { state.toggleFavorite(city) } label: {
                                Label(isJP ? "追加" : "Add", systemImage: "star")
                            }
                        }
                    }
                }
            }
        }
    }
}
