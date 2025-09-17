import SwiftUI
import Observation

struct ContentView: View {
    @State private var config = AppConfig()
    @Environment(\.locale) private var systemLocale   // ← システムのロケールを監視

    var body: some View {
        TabView {
            NavigationStack {
                SearchView()
                    .navigationTitle(isJapanese(config.locale) ? "検索" : "Search")
            }
            .tabItem { Label(isJapanese(config.locale) ? "検索" : "Search", systemImage: "magnifyingglass") }

            NavigationStack {
                FavoritesView()
                    .navigationTitle(isJapanese(config.locale) ? "お気に入り" : "Favorites")
            }
            .tabItem { Label(isJapanese(config.locale) ? "お気に入り" : "Favorites", systemImage: "star.fill") }
        }
        .tint(config.primaryTint)
        .environment(\.appConfig, config)
        .environment(\.locale, config.locale)  // ← AppConfigのlocaleを全体に注入
        .onAppear {
            config.locale = systemLocale       // ← 起動時に反映
        }
        .onChange(of: systemLocale) { _, newValue in
            config.locale = newValue           // ← 言語切替に追従
        }
    }
}
