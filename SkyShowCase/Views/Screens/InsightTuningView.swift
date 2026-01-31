//
//  InsightTuningView.swift
//  SkyShowCase
//
//  Created by 植村詩苑 on 2026/01/31.
//

import SwiftUI

// MARK: - Tuning Store (MVP)
struct InsightTuningStore {
    private static let prefix = "insight_tuning_bias_v1_" // + cityId

    static func loadBias(cityId: Int) -> Int {
        UserDefaults.standard.integer(forKey: prefix + String(cityId))
    }

    static func saveBias(_ bias: Int, cityId: Int) {
        UserDefaults.standard.set(bias, forKey: prefix + String(cityId))
    }
}

// MARK: - Tuning View (MVP)
struct InsightTuningView: View {
    @Environment(AppState.self) private var appState

    @State private var bias: Int = 0
    @State private var lastSavedAt: Date? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                header
                statusCard
                feedbackCard
                explainCard

            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .navigationTitle("調整")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .onChange(of: appState.selectedCity?.id) { _, _ in load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("通知の考え方を調整")
                .font(.title2).bold()
            Text("細かい設定より、結果へのフィードバックで学習させます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("現在の状態")
                .font(.headline)

            if let city = appState.selectedCity {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.secondary)
                    Text(city.name)
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Text("調整バイアス")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(biasLabel)
                        .font(.caption).fontWeight(.semibold)
                    Spacer()
                    if let lastSavedAt {
                        Text("更新: \(lastSavedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("都市が未選択です")
                    .font(.subheadline).fontWeight(.semibold)
                Text("ホームで都市を選ぶと、調整が反映されます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardContainerStyle()
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ワンタップ調整")
                .font(.headline)

            Text("最近の通知はどう感じた？")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button { applyBias(-1) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "bell.slash").font(.title3)
                        Text("多い").font(.caption).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button { applyBias(0) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle").font(.title3)
                        Text("ちょうど").font(.caption).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Button { applyBias(1) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "bell").font(.title3)
                        Text("少ない").font(.caption).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            .disabled(appState.selectedCity == nil)

            if appState.selectedCity == nil {
                Text("※ まずホームで都市を選んでください")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .cardContainerStyle()
    }

    private var explainCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("反映について")
                .font(.headline)

            Text("このフィードバックは、今後の通知の強さ（Hard/Soft/In-App）や抑制判断に影響します。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("しきい値などの詳細設定は、必要になった段階で追加します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardContainerStyle()
    }

    private var biasLabel: String {
        switch bias {
        case ..<0: return "減らし気味"
        case 0: return "標準"
        default: return "増やし気味"
        }
    }

    private func load() {
        guard let cityId = appState.selectedCity?.id else {
            bias = 0
            lastSavedAt = nil
            return
        }
        bias = InsightTuningStore.loadBias(cityId: cityId)
        lastSavedAt = nil
    }

    private func applyBias(_ newBias: Int) {
        guard let cityId = appState.selectedCity?.id else { return }
        bias = newBias
        InsightTuningStore.saveBias(newBias, cityId: cityId)
        lastSavedAt = Date()
    }
}
