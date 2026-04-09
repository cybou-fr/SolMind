import Foundation

// MARK: - Solana Stats ViewModel
// Provides live SOL price + network stats to any view that needs them.
// Persists last-known values to UserDefaults so the UI is never empty on launch.

@Observable
@MainActor
class SolanaStatsViewModel {
    var networkStats: SolanaNetworkStats?
    var solPrice: Double?
    var isRefreshing = false

    private let priceService = PriceService.shared
    private let networkService = SolanaNetworkService.shared

    private enum Keys {
        static let networkStats = "solana.networkStats.v1"
        static let solPrice = "solana.solPrice.v1"
    }

    init() {
        loadFromCache()
    }

    // MARK: - Refresh

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        async let statsFetch = networkService.getNetworkStats()
        async let priceFetch: Double? = (try? await priceService.getPrice(symbol: "SOL")) ?? nil

        networkStats = await statsFetch
        solPrice = await priceFetch
        persist()
    }

    // MARK: - Formatted helpers for UI

    var solPriceFormatted: String {
        guard let p = solPrice else { return "SOL --" }
        return "SOL $\(p.formatted(.number.precision(.fractionLength(2))))"
    }

    var epochFormatted: String {
        guard let s = networkStats else { return "" }
        return "Epoch \(s.currentEpoch) (\(s.epochProgressPercent))"
    }

    var tpsFormatted: String {
        networkStats?.tpsFormatted ?? ""
    }

    /// Compact summary line for injecting into AI context
    var contextSummary: String {
        var parts: [String] = []
        if let p = solPrice { parts.append("SOL $\(String(format: "%.2f", p))") }
        if let s = networkStats {
            parts.append("Epoch \(s.currentEpoch) (\(s.epochProgressPercent))")
            if let tps = s.tpsFormatted { parts.append(tps) }
        }
        return parts.joined(separator: " | ")
    }

    // MARK: - Persistence (UserDefaults)

    private func persist() {
        if let stats = networkStats,
           let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: Keys.networkStats)
        }
        if let price = solPrice {
            UserDefaults.standard.set(price, forKey: Keys.solPrice)
        }
    }

    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: Keys.networkStats),
           let stats = try? JSONDecoder().decode(SolanaNetworkStats.self, from: data) {
            networkStats = stats
        }
        let price = UserDefaults.standard.double(forKey: Keys.solPrice)
        if price > 0 { solPrice = price }
    }
}
