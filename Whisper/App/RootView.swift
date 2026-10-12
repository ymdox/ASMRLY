import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        HomeView(companion: coordinator.companion) { ambience in
            coordinator.start(ambience: ambience)
        }
        .sheet(
            isPresented: $coordinator.isShowingPermissionPrimer,
            onDismiss: { coordinator.primerDismissed() }
        ) {
            MicrophonePrimerView(
                onContinue: { coordinator.primerContinue() },
                onNotNow: { coordinator.primerNotNow() }
            )
        }
        .fullScreenCover(item: $coordinator.activeSession) { session in
            LiveSessionView(session: session) {
                coordinator.closeSession()
            }
        }
    }
}
