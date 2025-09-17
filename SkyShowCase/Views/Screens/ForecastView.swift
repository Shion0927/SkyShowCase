import SwiftUI
import UserNotifications
import UIKit

struct ForecastView: View {
    @Environment(\.appConfig) private var config
    let city: OpenMeteoCity
    @EnvironmentObject private var state: AppState

    // Notifications / UI state
    @State private var hasScheduledNotification = false
    @State private var showNotificationSettingsAlert = false
    @State private var snackbarMessage: String? = nil
    @State private var showSnackbar = false
    @State private var showNotificationSheet = false
    @State private var rule: NotificationRule = .defaultRule

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
        .task { state.loadForecast(for: city) }
        .task { await refreshScheduledState() }
        .task { rule = NotificationRule.load(for: city.id) ?? .defaultRule }
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
                            Text(isJapanese(config.locale) ? "通知を編集" : "Edit notification")
                        }
                        Button(role: .destructive) {
                            Task {
                                await disableNotifications()
                            }
                        } label: {
                            Text(isJapanese(config.locale) ? "通知を解除" : "Disable notification")
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
                title: Text(isJapanese(config.locale) ? "通知がオフです" : "Notifications Disabled"),
                message: Text(isJapanese(config.locale) ? "設定アプリで通知を許可してください。" : "Please allow notifications in Settings."),
                primaryButton: .default(Text(isJapanese(config.locale) ? "設定を開く" : "Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel(Text(isJapanese(config.locale) ? "キャンセル" : "Cancel"))
            )
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
                            Text(isJapanese(config.locale) ? "通知設定" : "Notification")
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
                            Task {
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
                                    showSnack(isJapanese(config.locale) ? "通知を設定しました" : "Notification scheduled")
                                }
                                withAnimation(.easeOut(duration: 0.2)) { showNotificationSheet = false }
                            }
                        } onDelete: {
                            Task {
                                await disableNotifications() // includes .today/.tomorrow
                                withAnimation(.easeOut(duration: 0.2)) { showNotificationSheet = false }
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
        isJapanese(locale) ? "体感 \(apparent) / 風 \(wind) m/s" : "Feels like \(apparent) / Wind \(wind) m/s"
    }

    private func localizedForecastHeader(for locale: Locale) -> String {
        isJapanese(locale) ? "7日予報" : "7-Day Forecast"
    }

    // === Notifications helpers ===
    private func refreshScheduledState() async {
        hasScheduledNotification = await NotificationScheduler.isScheduled(for: city.id)
    }

    private func showSnack(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            snackbarMessage = text
            showSnackbar = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.25)) { showSnackbar = false }
        }
    }

    private func scheduleAccordingToRule(_ rule: NotificationRule) async -> Bool {
        let ok = await NotificationScheduler.schedule(rule: rule, for: city.id, cityName: city.name, forecast: state.forecast, locale: config.locale)
        NotificationRule.save(rule, for: city.id)
        return ok
    }

    private func disableNotifications() async {
        // 予約済み通知をキャンセル
        await NotificationScheduler.cancel(for: city.id)
        // 状態更新
        await refreshScheduledState()
        showSnack(isJapanese(config.locale) ? "通知を解除しました" : "Notification disabled")
    }
}
