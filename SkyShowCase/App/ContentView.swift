import SwiftUI
import Observation

struct ContentView: View {
    private enum Tab: Hashable { case search, favorites, settings }
    @State private var selectedTab: Tab = .search
    @State private var favoritesPath = NavigationPath()
    @AppStorage("temperatureUnitPref") private var temperatureUnitPrefRaw: String = "system"
    @AppStorage("appearancePref") private var appearancePrefRaw: String = "system"

    private var preferredScheme: ColorScheme? {
        switch appearancePrefRaw {
        case "light": return .light
        case "dark":  return .dark
        default:       return nil
        }
    }

    @State private var config = AppConfig()
    @Environment(\.locale) private var systemLocale

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SearchView()
                    .navigationTitle("tab.search")
            }
            .tabItem { Label(String(localized: .init("tab.search")), systemImage: "magnifyingglass") }
            .tag(Tab.search)

            NavigationStack(path: $favoritesPath) {
                FavoritesView()
                    .navigationTitle("tab.favorites")
            }
            .tabItem { Label(String(localized: .init("tab.favorites")), systemImage: "star.fill") }
            .tag(Tab.favorites)

            // Settings tab
            NavigationStack {
                SettingsView()
                    .navigationTitle("tab.settings")
            }
            .tabItem { Label(String(localized: .init("tab.settings")), systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .id(temperatureUnitPrefRaw)
        .tint(config.primaryTint)
        .environment(\.appConfig, config)
        .environment(\.locale, config.locale)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            config.locale = systemLocale       // ← 起動時に反映
        }
        .onChange(of: systemLocale) { _, newValue in
            config.locale = newValue           // ← 言語切替に追従
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .favorites {
                favoritesPath = NavigationPath() 
            }
        }
    }
}
