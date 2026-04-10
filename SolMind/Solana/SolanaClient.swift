import Foundation

// MARK: - Solana JSON-RPC Client

actor SolanaClient {
    /// When non-nil this URL is always used (e.g. FaucetTool hardcodes specific providers).
    /// When nil, rpcURL is re-evaluated on every request so a key entered in Settings takes
    /// effect immediately without recreating the client.
    private let _fixedURL: URL?
    private var rpcURL: URL { _fixedURL ?? SolanaNetwork.rpcURL }
    private var urlSession: URLSession   // var — recreated on QUIC/connection-loss errors
    private var requestID = 0

    init(rpcURL: URL? = nil) {
        self._fixedURL = rpcURL
        self.urlSession = Self.makeSession()
    }

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30   // 30 s per individual request
        config.timeoutIntervalForResource = 90  // 90 s total across retries
        return URLSession(configuration: config)
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

    // MARK: - getAccountInfo

    /// Returns on-chain account metadata for any address.
    /// Returns nil if the account does not exist.
    func getAccountInfo(address: String) async throws -> OnChainAccountInfo? {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": nextID(),
            "method": "getAccountInfo",
            "params": [
                address,
                ["encoding": "base64", "commitment": "confirmed"]
            ]
        ]
        let data = try await postRaw(body: body)
        let decoded = try JSONDecoder().decode(RPCResponse<AccountInfoResult>.self, from: data)
        return decoded.result?.value
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
        // getSignatureStatuses returns { result: { context: {...}, value: [status_or_null, ...] } }
        // NOT result: [status_or_null, ...] — so we need a wrapper struct.
        struct SigStatusesResult: Decodable {
            let value: [SignatureStatus?]
        }
        for _ in 0..<maxAttempts {
            let data = try await postRPC(method: "getSignatureStatuses",
                                        params: [[signature], ["searchTransactionHistory": false]])
            let decoded = try JSONDecoder().decode(RPCResponse<SigStatusesResult>.self, from: data)
            if let status = decoded.result?.value.first ?? nil {
                if status.confirmationStatus == "confirmed" || status.confirmationStatus == "finalized" {
                    return status.err == nil
                }
            }
            try await Task.sleep(nanoseconds: 1_500_000_000)
        }
        // Timed out — throw instead of returning false so callers can surface the issue
        throw RPCError(code: -32002, message: "Transaction not confirmed after \(maxAttempts) attempts (~\(maxAttempts * 2)s). It may still be processing — check the Explorer.")
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

        // Retry up to 5 times on transient errors; backoff: 1s, 2s, 3s, 4s
        // On connection-loss (QUIC/HTTP3 drop), recreate the URLSession before retrying.
        let delays: [UInt64] = [1_000_000_000, 2_000_000_000, 3_000_000_000, 4_000_000_000]
        var lastError: Error?
        for attempt in 0..<5 {
            do {
                let (data, _) = try await urlSession.data(for: urlRequest)
                return data
            } catch let urlError as URLError where isTransientURLError(urlError) && attempt < 4 {
                lastError = urlError
                // QUIC/HTTP3 connections can drop silently; recreate session to force new connection
                if urlError.code == .networkConnectionLost {
                    urlSession = Self.makeSession()
                }
                try? await Task.sleep(nanoseconds: delays[min(attempt, 3)])
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
