import SwiftUI

struct RootView: View {
    var body: some View {
        HomeView(companion: .luna, onStart: { _ in })
    }
}
