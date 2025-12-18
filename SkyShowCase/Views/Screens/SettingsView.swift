import SwiftUI

struct SettingsView: View {
    @AppStorage("temperatureUnitPref") private var temperatureUnitPrefRaw: String = "system"
    @State private var isUnitExpanded = false

    // Theme
    @AppStorage("appearancePref") private var appearancePrefRaw: String = "system"
    @State private var isThemeExpanded = false

    // Equal-width columns for option rows
    @State private var unitLabelWidth: CGFloat = 0
    @State private var themeLabelWidth: CGFloat = 0

    var body: some View {
        Form {
            // 温度単位セクション
            Section(header: Text(String(localized: .init("settings.section.temperature")))) {
                // 押下で開閉
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isUnitExpanded.toggle() }
                } label: {
                    HStack {
                        Text(String(localized: .init("settings.picker.temperature")))
                        Spacer()
                        Text(currentUnitLabel())
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isUnitExpanded ? 180 : 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isUnitExpanded {
                    VStack(spacing: 0) {
                        optionRow(.system)
                        Divider()
                        optionRow(.celsius)
                        Divider()
                        optionRow(.fahrenheit)
                    }
                    .onPreferenceChange(UnitLabelWidthKey.self) { w in
                        unitLabelWidth = max(unitLabelWidth, w)
                    }
                }

                Text(String(localized: .init("settings.note.applies_globally")))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // テーマセクション
            Section(header: Text(String(localized: .init("settings.section.theme")))) {
                // 押下で開閉
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isThemeExpanded.toggle() }
                } label: {
                    HStack {
                        Text(String(localized: .init("settings.picker.theme")))
                        Spacer()
                        Text(currentThemeLabel())
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isThemeExpanded ? 180 : 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isThemeExpanded {
                    VStack(spacing: 0) {
                        themeOptionRow("system")
                        Divider()
                        themeOptionRow("light")
                        Divider()
                        themeOptionRow("dark")
                    }
                    .onPreferenceChange(ThemeLabelWidthKey.self) { w in
                        themeLabelWidth = max(themeLabelWidth, w)
                    }
                }

                Text(String(localized: .init("settings.theme.note.applies_immediately")))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // その他セクション
            Section(header: Text(String(localized: .init("settings.section.misc")))) {
                Text(String(localized: .init("settings.misc.placeholder")))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func currentUnitLabel() -> String {
        switch TemperatureUnitPref(rawValue: temperatureUnitPrefRaw) ?? .system {
        case .system:
            return String(localized: .init("settings.unit.system")).localizedUppercase
        case .celsius:
            return String(localized: .init("settings.unit.celsius"))
        case .fahrenheit:
            return String(localized: .init("settings.unit.fahrenheit"))
        }
    }

    @ViewBuilder
    private func optionRow(_ pref: TemperatureUnitPref) -> some View {
        Button {
            // 1) 先に折りたたみアニメーションを実行
            withAnimation(.easeInOut(duration: 0.22)) {
                isUnitExpanded = false
            }
            // 2) アニメーション完了後に値を確定（AppStorageを書き換えると画面全体が再描画されるため）
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(240))
                temperatureUnitPrefRaw = pref.rawValue
            }
        } label: {
            HStack {
                Text(label(for: pref))
                    .modifier(MeasureUnitWidth())
                    .frame(width: max(min(unitLabelWidth, 360), 120), alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if (TemperatureUnitPref(rawValue: temperatureUnitPrefRaw) ?? .system) == pref {
                    Image(systemName: "checkmark")
                        .font(.callout)
                        .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .frame(maxHeight: 48)
        }
        .buttonStyle(.plain)
    }

    private func label(for pref: TemperatureUnitPref) -> String {
        switch pref {
        case .system:
            return String(localized: .init("settings.unit.system")).localizedUppercase
        case .celsius:
            return String(localized: .init("settings.unit.celsius"))
        case .fahrenheit:
            return String(localized: .init("settings.unit.fahrenheit"))
        }
    }
    // Theme helpers
    private func currentThemeLabel() -> String {
        switch appearancePrefRaw {
        case "light": return String(localized: .init("settings.theme.light"))
        case "dark":  return String(localized: .init("settings.theme.dark"))
        default:       return String(localized: .init("settings.theme.system")).localizedUppercase
        }
    }

    @ViewBuilder
    private func themeOptionRow(_ raw: String) -> some View {
        Button {
            // 折りたたみを先に実行してから反映
            withAnimation(.easeInOut(duration: 0.22)) { isThemeExpanded = false }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(240))
                appearancePrefRaw = raw
            }
        } label: {
            HStack {
                Text(themeLabel(for: raw))
                    .modifier(MeasureThemeWidth())
                    .frame(width: max(min(themeLabelWidth, 360), 120), alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if appearancePrefRaw == raw {
                    Image(systemName: "checkmark")
                        .font(.callout)
                        .foregroundStyle(.tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .frame(maxHeight: 48)
        }
        .buttonStyle(.plain)
    }

    private func themeLabel(for raw: String) -> String {
        switch raw {
        case "light": return String(localized: .init("settings.theme.light"))
        case "dark":  return String(localized: .init("settings.theme.dark"))
        default:       return String(localized: .init("settings.theme.system")).localizedUppercase
        }
    }
}

private struct UnitLabelWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ThemeLabelWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct MeasureUnitWidth: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(key: UnitLabelWidthKey.self, value: proxy.size.width)
            }
        )
    }
}

private struct MeasureThemeWidth: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(key: ThemeLabelWidthKey.self, value: proxy.size.width)
            }
        )
    }
}

