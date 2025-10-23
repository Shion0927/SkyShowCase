import SwiftUI
import UserNotifications
import UIKit
import Observation

struct ForecastView: View {
    @Environment(\.appConfig) private var config
    let city: OpenMeteoCity
    @Environment(AppState.self) private var state
    @State private var isAlive = false
    @State private var asyncTask: Task<Void, Never>? = nil

    // Notifications / UI state
    @State private var hasScheduledNotification = false
    @State private var showNotificationSettingsAlert = false
    @State private var snackbarMessage: String? = nil
    @State private var showSnackbar = false
    @State private var showNotificationSheet = false
    @State private var rule: NotificationRule = .defaultRule
    @State private var snackTask: Task<Void, Never>? = nil

    var body: some View {
        List {
            if let f = state.forecast {
                // Advice
                Section {
                    Text(ClothingAdvisor.advice(current: f.current, locale: config.locale))
                }

                // Current weather
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: weatherSymbol(for: f.current.weather_code))
                            .font(.system(size: 44))
                        VStack(alignment: .leading) {
                            Text("\(formatTemperature(f.current.temperature_2m, locale: config.locale))")
                                .font(.system(size: 38, weight: .bold))
                            Text(
                                localizedCurrentDetail(
                                    for: config.locale,
                                    apparent: formatTemperature(f.current.apparent_temperature, locale: config.locale),
                                    wind: Int(f.current.wind_speed_10m)
                                )
                            )
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                // 7-day forecast
                Section(header: Text(localizedForecastHeader(for: config.locale))) {
                    ForEach(0..<min(f.daily.time.count, 7), id: \.self) { i in
                        HStack {
                            Text(shortDateText(f.daily.time[i], locale: config.locale))
                            Spacer()
                            Image(systemName: weatherSymbol(for: f.daily.weather_code[i]))
                            Text("\(formatTemperature(f.daily.temperature_2m_min[i], locale: config.locale)) - \(formatTemperature(f.daily.temperature_2m_max[i], locale: config.locale))")
                                .monospacedDigit()
                        }
                    }
                }
                .id(config.locale.identifier)
            } else {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
            }
        }
        .navigationTitle(city.name)
        .task { @MainActor in state.loadForecast(for: city) }
        .task { @MainActor in await refreshScheduledState() }
        .task { @MainActor in rule = NotificationRule.load(for: city.id) ?? .defaultRule }
        .toolbar {
            // Favorite toggle
            ToolbarItem(placement: .topBarTrailing) {
                Button { state.toggleFavorite(city) } label: {
                    Image(systemName: state.isFavorite(city) ? "star.fill" : "star")
                }
            }
            // Notification settings (open sheet if none; show menu if configured)
            ToolbarItem(placement: .topBarTrailing) {
                if hasScheduledNotification {
                    Menu {
                        Button {
                            showNotificationSheet = true
                        } label: {
                            Text(String(localized: .init("notification.edit")))
                        }
                        Button(role: .destructive) {
                            asyncTask = Task { @MainActor in
                                await disableNotifications()
                            }
                        } label: {
                            Text(String(localized: .init("notification.disable")))
                        }
                    } label: {
                        Image(systemName: "bell.fill")
                    }
                    .menuIndicator(.hidden)
                } else {
                    Button { showNotificationSheet = true } label: {
                        Image(systemName: "bell")
                    }
                }
            }
        }
        .alert(isPresented: $showNotificationSettingsAlert) {
            Alert(
                title: Text(String(localized: .init("alert.notifications_disabled.title"))),
                message: Text(String(localized: .init("alert.notifications_disabled.message"))),
                primaryButton: .default(Text(String(localized: .init("alert.notifications_disabled.open_settings")))) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel(Text(String(localized: .init("common.cancel"))))
            )
        }
        .onAppear { isAlive = true }
        .onDisappear {
            isAlive = false
            asyncTask?.cancel()
            snackTask?.cancel()
            snackTask = nil
        }
        // ===== Centered modal for notification settings =====
        .overlay(alignment: .center) {
            if showNotificationSheet {
                ZStack {
                    // Dim
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showNotificationSheet = false } }

                    // Card
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text(String(localized: .init("notification.settings.title")))
                                .font(.headline)
                            Spacer()
                            Button { withAnimation(.easeOut(duration: 0.2)) { showNotificationSheet = false } } label: {
                                Image(systemName: "xmark").font(.body)
                            }
                        }
                        .padding()

                        Divider()

                        // Content
                        NotificationSettingsView(rule: $rule, locale: config.locale) {
                            asyncTask = Task { @MainActor in
                                let allowed = await ensureNotificationAuthorization()
                                if !allowed {
                                    showNotificationSettingsAlert = true
                                    return
                                }
                                let ok = await scheduleAccordingToRule(rule)
                                if !ok {
                                    showNotificationSettingsAlert = true
                                } else {
                                    // Per-day scheduling
                                    if rule.enableToday {
                                        await NotificationScheduler.scheduleToday(for: city.id, cityName: city.name, hour: rule.todayHour, minute: rule.todayMinute, locale: config.locale, forecast: state.forecast)
                                    } else {
                                        await NotificationScheduler.cancelToday(for: city.id)
                                    }
                                    if rule.enableTomorrow {
                                        await NotificationScheduler.scheduleTomorrow(for: city.id, cityName: city.name, hour: rule.tomorrowHour, minute: rule.tomorrowMinute, locale: config.locale, forecast: state.forecast)
                                    } else {
                                        await NotificationScheduler.cancelTomorrow(for: city.id)
                                    }
                                    await refreshScheduledState()
                                    guard isAlive else { return }
                                    DispatchQueue.main.async {
                                        // Close sheet without UIKit animations (Release含む恒久対策)
                                        UIView.setAnimationsEnabled(false)
                                        showNotificationSheet = false
                                        UIView.setAnimationsEnabled(true)
                                        // Show snackbar after the sheet has fully closed to avoid trait-change collisions on iOS 26
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                            guard isAlive else { return }
                                            showSnack(String(localized: .init("notification.scheduled")))
                                        }
                                    }
                                }
                            }
                        } onDelete: {
                            asyncTask = Task { @MainActor in
                                await disableNotifications() // includes .today/.tomorrow
                                guard isAlive else { return }
                                DispatchQueue.main.async {
                                    // Close sheet without UIKit animations (Release含む恒久対策)
                                    UIView.setAnimationsEnabled(false)
                                    showNotificationSheet = false
                                    UIView.setAnimationsEnabled(true)
                                }
                            }
                        }
                        .frame(maxHeight: 560)

                    }
                    .frame(maxWidth: 700)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 24)
                    .padding(24)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        // Snackbar
        .overlay(alignment: .bottom) {
            if showSnackbar, let message = snackbarMessage {
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(message)
            }
        }
    }

    private func localizedCurrentDetail(for locale: Locale, apparent: String, wind: Int) -> String {
        let format = String(localized: .init("forecast.current_detail"))
        return String(format: format, locale: locale, apparent, wind)
    }

    private func localizedForecastHeader(for locale: Locale) -> String {
        String(localized: .init("forecast.header"))
    }

    // === Notifications helpers ===
    @MainActor
    private func refreshScheduledState() async {
        hasScheduledNotification = await NotificationScheduler.isScheduled(for: city.id)
    }

    @MainActor
    private func showSnack(_ text: String) {
        // Show after a short delay so it never collides with the sheet/menu closing animation in the same frame (iOS 26 safety)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard isAlive, !showNotificationSheet else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                snackbarMessage = text
                showSnackbar = true
            }
        }
        // Cancel any previous delayed task and schedule a new one that we can cancel on disappear
        snackTask?.cancel()
        snackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, isAlive else { return }
            withAnimation(.easeOut(duration: 0.25)) { showSnackbar = false }
        }
    }


    private func scheduleAccordingToRule(_ rule: NotificationRule) async -> Bool {
        let ok = await NotificationScheduler.schedule(rule: rule, for: city.id, cityName: city.name, forecast: state.forecast, locale: config.locale)
        NotificationRule.save(rule, for: city.id)
        return ok
    }

    @MainActor
    private func disableNotifications() async {
        // 予約済み通知をキャンセル
        await NotificationScheduler.cancelAll(for: city.id)
        // 状態更新
        await refreshScheduledState()
        showSnack(String(localized: .init("notification.disabled")))
    }

    private func ensureNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                return granted
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }
}
