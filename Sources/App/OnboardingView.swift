import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var token = ""
    @State private var isValidating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "clock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            // Title
            VStack(spacing: 6) {
                Text("Welcome to Tempo")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Connect your Noko account to get started")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Token input
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal Access Token")
                    .font(.callout)
                    .fontWeight(.medium)

                SecureField("Paste your Noko API token", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 360)

                Link("Get your token from Noko →",
                     destination: URL(string: "https://secure.nokotime.com/user/api/personal_access_tokens/new")!)
                    .font(.caption)
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: validate) {
                if isValidating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                } else {
                    Text("Connect")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(token.isEmpty || isValidating)

            Spacer()
        }
        .padding(40)
        .frame(width: 480, height: 400)
    }

    private func validate() {
        isValidating = true
        error = nil
        Task {
            do {
                try await appState.configure(token: token)
            } catch {
                self.error = "Failed to connect: \(error.localizedDescription)"
            }
            isValidating = false
        }
    }
}
