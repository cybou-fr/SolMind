import Foundation

// MARK: - Solana JSON-RPC Client

actor SolanaClient {
    private let rpcURL: URL
    private let urlSession: URLSession
    private var requestID = 0

    init(rpcURL: URL = SolanaNetwork.rpcURL) {
        self.rpcURL = rpcURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20   // 20 s per individual request
        config.timeoutIntervalForResource = 30  // 30 s total including retries
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - getBalance

    func getBalance(publicKey: String) async throws -> UInt64 {
        let data = try await postRPC(method: "getBalance",
                                    params: [publicKey, ["commitment": "confirmed"]])
        let decoded = try JSONDecoder().decode(RPCResponse<BalanceResult>.self, from: data)
        guard let value = decoded.result?.value else {
            throw decoded.error ?? RPCError(code: -1, message: "Empty balance response")
        }
        return value
    }

    /// Returns SOL balance in decimal (divides lamports by 1e9)
    func getSOLBalance(publicKey: String) async throws -> Double {
        let lamports = try await getBalance(publicKey: publicKey)
        return Double(lamports) / 1_000_000_000
    }

    // MARK: - getTokenAccountsByOwner

    func getTokenAccounts(owner: String) async throws -> [TokenAccount] {
        // Build raw JSON manually for this RPC call (heterogeneous params array)
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": nextID(),
            "method": "getTokenAccountsByOwner",
            "params": [
                owner,
                ["programId": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"],
                ["encoding": "jsonParsed"]
            ]
        ]

        let data = try await postRaw(body: body)
        let decoded = try JSONDecoder().decode(RPCResponse<TokenAccountsResponse>.self, from: data)

        guard let accounts = decoded.result?.value else {
            return []
        }

        return accounts.compactMap { info -> TokenAccount? in
            let tokenInfo = info.account.data.parsed.info
            guard let raw = UInt64(tokenInfo.tokenAmount.amount) else { return nil }
            return TokenAccount(
                pubkey: info.pubkey,
                mint: tokenInfo.mint,
                owner: tokenInfo.owner,
                decimals: tokenInfo.tokenAmount.decimals,
                rawAmount: raw,
                uiAmount: tokenInfo.tokenAmount.uiAmount ?? 0
            )
        }
    }

    // MARK: - requestAirdrop (devnet faucet)

    func requestAirdrop(to publicKey: String, lamports: UInt64) async throws -> String {
        let data = try await postRPC(method: "requestAirdrop",
                                    params: [publicKey, lamports, ["commitment": "confirmed"]])
        let decoded = try JSONDecoder().decode(RPCResponse<String>.self, from: data)
        guard let signature = decoded.result else {
            throw decoded.error ?? RPCError(code: -1, message: "Airdrop failed")
        }
        return signature
    }

    // MARK: - getLatestBlockhash

    func getLatestBlockhash() async throws -> String {
        let data = try await postRPC(method: "getLatestBlockhash",
                                    params: [["commitment": "confirmed"]])
        let decoded = try JSONDecoder().decode(RPCResponse<BlockhashResponse>.self, from: data)
        guard let blockhash = decoded.result?.value.blockhash else {
            throw decoded.error ?? RPCError(code: -1, message: "Could not fetch blockhash")
        }
        return blockhash
    }

    // MARK: - sendTransaction

    func sendTransaction(serialized: Data) async throws -> String {
        let base64Tx = serialized.base64EncodedString()
        let data = try await postRPC(method: "sendTransaction",
                                    params: [base64Tx, ["encoding": "base64", "preflightCommitment": "confirmed"]])
        let decoded = try JSONDecoder().decode(RPCResponse<String>.self, from: data)
        guard let signature = decoded.result else {
            throw decoded.error ?? RPCError(code: -1, message: "sendTransaction failed")
        }
        return signature
    }

    // MARK: - getSignaturesForAddress

    func getSignaturesForAddress(publicKey: String, limit: Int = 10) async throws -> [SignatureInfo] {
        let data = try await postRPC(method: "getSignaturesForAddress",
                                    params: [publicKey, ["limit": limit, "commitment": "confirmed"]])
        let decoded = try JSONDecoder().decode(RPCResponse<[SignatureInfo]>.self, from: data)
        return decoded.result ?? []
    }

    // MARK: - confirmTransaction (poll)

    func confirmTransaction(signature: String, maxAttempts: Int = 20) async throws -> Bool {
        for _ in 0..<maxAttempts {
            let data = try await postRPC(method: "getSignatureStatuses",
                                        params: [[signature], ["searchTransactionHistory": false]])
            let decoded = try JSONDecoder().decode(RPCResponse<[SignatureStatus?]>.self, from: data)
            if let statuses = decoded.result, let status = statuses.first ?? nil {
                if status.confirmationStatus == "confirmed" || status.confirmationStatus == "finalized" {
                    return status.err == nil
                }
            }
            try await Task.sleep(nanoseconds: 1_500_000_000)
        }
        return false
    }

    // MARK: - Private Helpers

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
        return try await postRaw(body: body)
    }

    private func postRaw(body: [String: Any]) async throws -> Data {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        var urlRequest = URLRequest(url: rpcURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = bodyData

        // Retry up to 3 times on transient network errors with exponential backoff
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let (data, _) = try await urlSession.data(for: urlRequest)
                return data
            } catch let urlError as URLError where isTransientURLError(urlError) && attempt < 2 {
                lastError = urlError
                // 500 ms, 1 000 ms
                let nanoseconds = UInt64(500_000_000) * UInt64(attempt + 1)
                try? await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                throw error
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    private func isTransientURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .notConnectedToInternet, .networkConnectionLost,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - getSignatureStatuses response additions

struct SignatureStatus: Decodable, Sendable {
    let slot: UInt64
    let confirmations: Int?
    let err: AnyCodable?
    let confirmationStatus: String?
}

// Simple wrapper for unknown JSON values
struct AnyCodable: Decodable, Sendable {}
