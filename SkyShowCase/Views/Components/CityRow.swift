import SwiftUI

struct CityRow: View {
    let city: OpenMeteoCity
    var body: some View {
        VStack(alignment: .leading) {
            Text(city.name).font(.headline)
            Text(locationSubtitle(admin1: city.admin1, countryCode: city.country_code))
                .foregroundStyle(.secondary)
        }
    }
}

