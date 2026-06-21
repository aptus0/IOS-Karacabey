import MapKit
import SwiftUI

struct NearbyBranchesMapView: View {
    let branches: [Branch]

    var body: some View {
        Map {
            ForEach(branches) { branch in
                Marker(branch.name, coordinate: branch.coordinate)
            }
        }
        .navigationTitle("Yakındaki Mağazalar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

