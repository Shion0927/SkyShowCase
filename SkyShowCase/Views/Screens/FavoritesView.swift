import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        List {
            if state.favorites.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Text("favorites.empty.title")
                        .foregroundStyle(.secondary)
                    Text("favorites.empty.hint")
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
        .navigationDestination(for: City.self) { city in
            ForecastView(city: city)
        }
        .toolbar {
            if !state.favorites.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }
}
