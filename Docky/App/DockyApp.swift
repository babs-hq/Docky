import SwiftUI

@main
struct DockyApp: App {
    @State private var signatureStore = SignatureStore()
    @State private var signatureLock = SignatureLock()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(signatureStore)
                .environment(signatureLock)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Leaving the app re-locks the signature.
            if newPhase == .background {
                signatureLock.lock()
            }
        }
    }
}
