import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        HomeView(companion: coordinator.companion) { ambience in
            coordinator.start(ambience: ambience)
        }
        .fullScreenCover(item: $coordinator.activeSession) { session in
            LiveSessionView(session: session) {
                coordinator.closeSession()
            }
        }
    }
}
