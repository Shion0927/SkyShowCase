import SwiftUI
import Observation

struct ContentView: View {
    private enum Tab: Hashable { case home, timeline, notifications, insight }
    @State private var selectedTab: Tab = .home
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
                HomeView()
                    .navigationTitle("tab.home")
            }
            .tabItem { Label(String(localized: .init("tab.home")), systemImage: "house") }
            .tag(Tab.home)

            NavigationStack {
                TimelineView()
                    .navigationTitle("tab.timeline")
            }
            .tabItem { Label(String(localized: .init("tab.timeline")), systemImage: "clock") }
            .tag(Tab.timeline)

            NavigationStack {
                NotificationsView()
                    .navigationTitle("tab.notifications")
            }
            .tabItem { Label(String(localized: .init("tab.notifications")), systemImage: "bell") }
            .tag(Tab.notifications)

            NavigationStack {
                InsightView()
                    .navigationTitle("tab.insight")
            }
            .tabItem { Label(String(localized: .init("tab.insight")), systemImage: "sparkles") }
            .tag(Tab.insight)
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
    }
}
