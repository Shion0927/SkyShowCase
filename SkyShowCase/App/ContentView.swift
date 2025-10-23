import SwiftUI
import Observation

struct ContentView: View {
    private enum Tab: Hashable { case search, favorites }
    @State private var selectedTab: Tab = .search
    @State private var favoritesPath = NavigationPath()
    @State private var config = AppConfig()
    @Environment(\.locale) private var systemLocale   // ← システムのロケールを監視

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SearchView()
                    .navigationTitle("tab.search")
            }
            .tabItem { Label("tab.search", systemImage: "magnifyingglass") }
            .tag(Tab.search)

            NavigationStack(path: $favoritesPath) {
                FavoritesView()
                    .navigationTitle("tab.favorites")
            }
            .tabItem { Label("tab.favorites", systemImage: "star.fill") }
            .tag(Tab.favorites)
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
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .favorites {
                favoritesPath = NavigationPath() // always pop to root when Favorites tab is selected
            }
        }
    }
}
