import SwiftUI

// MARK: - Solana Stats Bar
// Compact single-line header showing live SOL price, epoch progress, and TPS.

struct SolanaStatsBar: View {
    @Environment(SolanaStatsViewModel.self) private var statsVM
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // SOL price
                    statChip(
                        icon: "dollarsign.circle.fill",
                        text: statsVM.solPriceFormatted,
                        color: .green
                    )

                    if !statsVM.epochFormatted.isEmpty {
                        divider

                        // Epoch + progress
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                            Text(statsVM.epochFormatted)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)

                            // Epoch progress capsule
                            if let stats = statsVM.networkStats {
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.15))
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.accentColor.opacity(0.6))
                                                .frame(width: geo.size.width * stats.epochProgress)
                                        }
                                }
                                .frame(width: 40, height: 4)
                            }
                        }
                    }

                    if !statsVM.tpsFormatted.isEmpty {
                        divider
                        statChip(
                            icon: "bolt.fill",
                            text: statsVM.tpsFormatted,
                            color: .orange
                        )
                    }

                    if statsVM.isRefreshing {
                        divider
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 12)
            }

            // Refresh button
            Button {
                Task { await statsVM.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(statsVM.isRefreshing)
            .accessibilityLabel("Refresh Solana stats")
            .padding(.trailing, 10)
        }
        .frame(height: 28)
        .background(.bar)
        // Auto-refresh every 60 seconds while the bar is visible
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if !Task.isCancelled {
                    await statsVM.refresh()
                }
            }
        }
        // Refresh when app returns to foreground
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await statsVM.refresh() }
            }
        }
    }

    // MARK: - Sub-views

    private func statChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption2)
            Text(text)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var divider: some View {
        Text("·")
            .foregroundStyle(.tertiary)
            .font(.caption2)
    }
}

#Preview {
    SolanaStatsBar()
        .environment(SolanaStatsViewModel())
}
