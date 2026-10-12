import SwiftUI

struct SettingsView: View {
    @Environment(SignatureLock.self) private var signatureLock
    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Require \(signatureLock.methodName)", isOn: requiresAuthentication)
                } header: {
                    Text("Security")
                } footer: {
                    Text("Ask for \(signatureLock.methodName) before your saved signature can be placed on a document or changed.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Can't Turn On", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    /// The toggle only changes after authentication succeeds; if it fails,
    /// `isEnabled` stays the same and the switch slides back by itself.
    private var requiresAuthentication: Binding<Bool> {
        Binding(
            get: { signatureLock.isEnabled },
            set: { newValue in
                Task {
                    do {
                        try await signatureLock.setEnabled(newValue)
                    } catch {
                        errorMessage = error.localizedDescription
                        isShowingError = true
                    }
                }
            }
        )
    }
}

#Preview {
    SettingsView()
        .environment(SignatureLock())
}
