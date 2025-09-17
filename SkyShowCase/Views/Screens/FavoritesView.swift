import SwiftUI

struct FavoritesView: View {
    @Environment(\.appConfig) private var config
    @EnvironmentObject private var state: AppState

    var body: some View {
        List {
            if state.favorites.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Text(isJapanese(config.locale) ? "お気に入りはありません" : "No favorites yet")
                        .foregroundStyle(.secondary)
                    Text(isJapanese(config.locale) ? "検索から都市を追加してください" : "Add cities from Search")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                ForEach(state.favorites) { city in
                    NavigationLink(value: city) {
                        VStack(alignment: .leading) {
                            Text(city.name).font(.headline)
                            Text([city.admin1, countryName(from: city.country_code)].compactMap { $0 }.joined(separator: " "))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    for index in idx { state.toggleFavorite(state.favorites[index]) }
                }
            }
        }
        .navigationDestination(for: OpenMeteoCity.self) { city in
            ForecastView(city: city)
        }
        .toolbar {
            if !state.favorites.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }
}
