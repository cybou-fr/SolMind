import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @State private var showHeliusKey    = false
    @State private var showMoonpayKey   = false
    @State private var showClearConfirm = false

    var body: some View {
        @Bindable var settings = AppSettings.shared
        List {
            apiKeysSection(settings: $settings)
            networkSection
            preferencesSection(settings: $settings)
            aiTelemetrySection
            aboutSection
            dangerZoneSection
        }
        .navigationTitle("Settings")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .confirmationDialog(
            "Clear All Conversations?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                let all = chatViewModel.conversations
                for convo in all {
                    chatViewModel.deleteConversation(convo)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All conversation history will be permanently deleted. This cannot be undone.")
        }
    }

    // MARK: - API Keys Section

    @ViewBuilder
    private func apiKeysSection(settings: Bindable<AppSettings>) -> some View {
        Section {
            apiKeyRow(
                label: "Helius API Key",
                hint: "NFT minting & DAS queries — get a free key at helius.dev",
                value: settings.heliusAPIKey,
                placeholder: "YOUR_HELIUS_DEVNET_KEY",
                isVisible: $showHeliusKey
            )
            apiKeyRow(
                label: "MoonPay API Key",
                hint: "Fiat on-ramp sandbox — get a key at moonpay.com",
                value: settings.moonpayAPIKey,
                placeholder: "YOUR_MOONPAY_SANDBOX_KEY",
                isVisible: $showMoonpayKey
            )
            if !settings.heliusAPIKey.wrappedValue.isEmpty || !settings.moonpayAPIKey.wrappedValue.isEmpty {
                Button("Reset to Built-in Defaults") {
                    AppSettings.shared.resetAPIKeys()
                }
                .foregroundStyle(.secondary)
            }
        } header: {
            Label("API Keys", systemImage: "key.fill")
        } footer: {
            Text("Keys are stored locally on this device. Leave blank to use the app's built-in defaults.")
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        Section {
            LabeledContent("Cluster") {
                Text("devnet")
                    .foregroundStyle(.orange)
                    .font(.caption.monospaced())
            }
            LabeledContent("RPC Endpoint") {
                Text("api.devnet.solana.com")
                    .foregroundStyle(.secondary)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            LabeledContent("Explorer") {
                Text("explorer.solana.com")
                    .foregroundStyle(.secondary)
                    .font(.caption.monospaced())
            }
        } header: {
            Label("Network", systemImage: "antenna.radiowaves.left.and.right")
        } footer: {
            Text("SolMind runs exclusively on Solana devnet. Real assets and mainnet are not supported.")
        }
    }

    // MARK: - Preferences Section

    @ViewBuilder
    private func preferencesSection(settings: Bindable<AppSettings>) -> some View {
        Section {
#if os(iOS)
            Toggle(isOn: settings.hapticFeedbackEnabled) {
                Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
            }
#endif
            LabeledContent("AI Engine") {
                Text("On-Device · Foundation Models")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            LabeledContent("AI Privacy") {
                Text("Fully private, no data leaves device")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        } header: {
            Label("Preferences", systemImage: "slider.horizontal.3")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Built With") {
                Text("Swift · SwiftUI · FoundationModels")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Link(destination: URL(string: "https://explorer.solana.com/?cluster=devnet")!) {
                Label("Solana Explorer (devnet)", systemImage: "magnifyingglass")
            }
            Link(destination: URL(string: "https://faucet.solana.com")!) {
                Label("Devnet Faucet", systemImage: "drop.fill")
            }
            Link(destination: URL(string: "https://helius.dev")!) {
                Label("Helius Dashboard", systemImage: "globe")
            }
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    // MARK: - Danger Zone Section

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("Clear All Conversations", systemImage: "trash")
            }
        } header: {
            Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    // MARK: - AI Telemetry Section (OPT-10)

    private var aiTelemetrySection: some View {
        Section {
            LabeledContent("Last Prompt") {
                Text("\(chatViewModel.lastPromptTokenEstimate) tokens")
                    .foregroundStyle(chatViewModel.lastPromptTokenEstimate > 3_000 ? .red :
                                     chatViewModel.lastPromptTokenEstimate > 2_000 ? .orange : .secondary)
                    .font(.caption.monospacedDigit())
            }
            LabeledContent("Session Total") {
                Text("\(chatViewModel.sessionTokensUsed) tokens")
                    .foregroundStyle(.secondary)
                    .font(.caption.monospacedDigit())
            }
            LabeledContent("Context Budget") {
                let pct = chatViewModel.lastPromptTokenEstimate > 0
                    ? Int(Double(chatViewModel.lastPromptTokenEstimate) / 4096.0 * 100)
                    : 0
                Text("\(pct)% of 4096")
                    .foregroundStyle(pct > 75 ? .red : pct > 50 ? .orange : .green)
                    .font(.caption.monospacedDigit())
            }
            LabeledContent("Last Response") {
                if let t = chatViewModel.lastResponseTime {
                    Text(String(format: "%.2f s", t))
                        .foregroundStyle(t > 3 ? .orange : .secondary)
                        .font(.caption.monospacedDigit())
                } else {
                    Text("—").foregroundStyle(.secondary).font(.caption)
                }
            }
            LabeledContent("Session Messages") {
                Text("\(chatViewModel.sessionMessageCount)")
                    .foregroundStyle(.secondary)
                    .font(.caption.monospacedDigit())
            }
            LabeledContent("Session Transactions") {
                Text("\(chatViewModel.sessionTransactionCount)")
                    .foregroundStyle(.secondary)
                    .font(.caption.monospacedDigit())
            }
            // OPT-09: Knowledge version
            LabeledContent("Knowledge Version") {
                @Bindable var updater = KnowledgeUpdater.shared
                Text(updater.remoteVersion ?? "built-in")
                    .foregroundStyle(updater.remoteVersion != nil ? .green : .secondary)
                    .font(.caption.monospacedDigit())
            }
            Button {
                Task { await KnowledgeUpdater.shared.forceRefresh() }
            } label: {
                Label(
                    KnowledgeUpdater.shared.isFetching ? "Refreshing…" : "Refresh Knowledge Block",
                    systemImage: "arrow.clockwise"
                )
            }
            .disabled(KnowledgeUpdater.shared.isFetching)
            if KnowledgeUpdater.shared.overrideSystemBlock != nil {
                Button(role: .destructive) {
                    KnowledgeUpdater.shared.clearOverride()
                } label: {
                    Label("Reset to Built-in Knowledge", systemImage: "xmark.circle")
                }
            }
        } header: {
            Label("AI Telemetry", systemImage: "chart.bar.fill")
        } footer: {
            Text("Token estimates use 4 chars ≈ 1 token. Budget is the 4 096-token Foundation Models context window. Values reset on New Chat. Knowledge Block can be updated remotely without an app release.")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (build \(b))"
    }

    @ViewBuilder
    private func apiKeyRow(
        label: String,
        hint: String,
        value: Binding<String>,
        placeholder: String,
        isVisible: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: value)
                        .noAutoCapitalize()
                } else {
                    SecureField(placeholder, text: value)
                }
            }
            .font(.caption.monospaced())
            .autocorrectionDisabled()
            Text(hint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Cross-platform helper

private extension View {
    @ViewBuilder
    func noAutoCapitalize() -> some View {
#if os(iOS)
        self.textInputAutocapitalization(.never)
#else
        self
#endif
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(ChatViewModel())
}
