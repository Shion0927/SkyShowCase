import SwiftUI

struct CurrentLocationSectionView: View {
    @Environment(\.appConfig) private var config
    @Binding var currentLocationCity: OpenMeteoCity?
    @Binding var isFetchingLocation: Bool
    let fetchCurrentLocation: () async -> Void

    var body: some View {
        let isJP = isJapanese(config.locale)
        Section(header: Text(isJP ? "現在地" : "Current Location")) {
            if let city = currentLocationCity {
                NavigationLink(value: city) {
                    CityRow(city: city)
                }
            } else {
                HStack {
                    Label(isJP ? "現在地" : "Current", systemImage: "location.fill")
                    Spacer()
                    if isFetchingLocation {
                        ProgressView()
                    } else {
                        Button(isJP ? "取得" : "Fetch") {
                            Task { await fetchCurrentLocation() }
                        }
                    }
                }
            }
        }
    }
}


