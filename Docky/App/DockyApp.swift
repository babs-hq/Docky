import SwiftUI

@main
struct DockyApp: App {
    @State private var signatureStore = SignatureStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(signatureStore)
        }
    }
}
