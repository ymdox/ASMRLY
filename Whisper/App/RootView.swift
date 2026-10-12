import SwiftUI

struct RootView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        HomeView(
            companion: coordinator.companion,
            onStart: { ambience in coordinator.start(ambience: ambience) },
            diagnostics: diagnosticsCard
        )
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
        #if DEBUG
        .task {
            try? await Task.sleep(for: .seconds(1))
            coordinator.autoStartIfRequested()
        }
        .task {
            await coordinator.checkProviders()
        }
        #endif
    }

    private var diagnosticsCard: AnyView? {
        #if DEBUG
        return AnyView(
            ConnectionStatusCard(
                checks: coordinator.providerChecks,
                isChecking: coordinator.isCheckingProviders,
                onRecheck: { Task { await coordinator.checkProviders() } }
            )
        )
        #else
        return nil
        #endif
    }
}
