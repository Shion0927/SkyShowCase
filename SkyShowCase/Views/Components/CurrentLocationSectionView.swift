import SwiftUI

struct CurrentLocationSectionView: View {
    @Environment(\.appConfig) private var config
    @Binding var currentLocationCity: OpenMeteoCity?
    @Binding var isFetchingLocation: Bool
    let fetchCurrentLocation: () async -> Void

    var body: some View {
        Section(header: Text("current_location_section.header")) {
            if let city = currentLocationCity {
                NavigationLink(value: city) {
                    CityRow(city: city)
                }
            } else {
                HStack {
                    Label("current_location_section.current", systemImage: "location.fill")
                    Spacer()
                    if isFetchingLocation {
                        ProgressView()
                    } else {
                        Button("current_location_section.fetch") {
                            Task { await fetchCurrentLocation() }
                        }
                    }
                }
            }
        }
    }
}
