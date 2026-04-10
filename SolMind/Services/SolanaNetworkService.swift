import Foundation

// MARK: - Solana Network Stats Model

struct SolanaNetworkStats: Codable {
    let currentEpoch: UInt64
    let slotIndex: UInt64
    let slotsInEpoch: UInt64
    let absoluteSlot: UInt64
    let tps: Double?
    let fetchedAt: Date

    var epochProgress: Double {
        guard slotsInEpoch > 0 else { return 0 }
        return min(1.0, Double(slotIndex) / Double(slotsInEpoch))
    }

    var epochProgressPercent: String {
        String(format: "%.0f%%", epochProgress * 100)
    }

    var tpsFormatted: String? {
        guard let t = tps else { return nil }
        return String(format: "~%.0f TPS", t)
    }
}

// MARK: - Solana Network Service

actor SolanaNetworkService {
    static let shared = SolanaNetworkService()

    private var cachedStats: SolanaNetworkStats?
    private let cacheTTL: TimeInterval = 120  // 2 minutes
    // Read UserDefaults directly (thread-safe, no actor boundary) so Settings changes take effect.
    private var rpcURL: URL { SolanaNetwork.rpcURL }
    private var requestID = 0

    // MARK: - Public API

    /// Returns cached stats if fresh, otherwise fetches from RPC.
    func getNetworkStats() async -> SolanaNetworkStats? {
        if let cached = cachedStats,
           Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached
        }
        return await fetchAndCache()
    }

    // MARK: - Fetching

    private func fetchAndCache() async -> SolanaNetworkStats? {
        // Run both RPC calls concurrently
        async let epochData = postRPC(method: "getEpochInfo", params: [])
        async let perfData = postRPC(method: "getRecentPerformanceSamples",
                                     params: [1])

        guard let eData = try? await epochData else { return nil }

        guard let epochInfo = try? JSONDecoder()
            .decode(RPCResponse<NetworkEpochResult>.self, from: eData).result else { return nil }

        let resolvedPerfData = try? await perfData
        var tps: Double? = nil
        if let pData = resolvedPerfData,
           let samples = try? JSONDecoder()
                .decode(RPCResponse<[NetworkPerfSample]>.self, from: pData).result,
           let first = samples.first,
           first.samplePeriodSecs > 0 {
            tps = Double(first.numTransactions) / Double(first.samplePeriodSecs)
        }

        let stats = SolanaNetworkStats(
            currentEpoch: epochInfo.epoch,
            slotIndex: epochInfo.slotIndex,
            slotsInEpoch: epochInfo.slotsInEpoch,
            absoluteSlot: epochInfo.absoluteSlot,
            tps: tps,
            fetchedAt: Date()
        )
        cachedStats = stats
        return stats
    }

    // MARK: - RPC Helper

    private func nextID() -> Int {
        requestID += 1
        return requestID
    }

    private func postRPC(method: String, params: [Any]) async throws -> Data {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": nextID(),
            "method": method,
            "params": params
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}

// MARK: - Decode types (file scope — avoids Swift 6 actor-isolation inheritance)

private struct NetworkEpochResult: Decodable, Sendable {
    let absoluteSlot: UInt64
    let epoch: UInt64
    let slotIndex: UInt64
    let slotsInEpoch: UInt64
}

private struct NetworkPerfSample: Decodable, Sendable {
    let numTransactions: UInt64
    let samplePeriodSecs: UInt16
}
