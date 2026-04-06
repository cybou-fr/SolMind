import Foundation

// MARK: - Solana JSON-RPC Client

actor SolanaClient {
    private let rpcURL: URL
    private let urlSession: URLSession
    private var requestID = 0

    init(rpcURL: URL = SolanaNetwork.rpcURL) {
        self.rpcURL = rpcURL
        self.urlSession = URLSession(configuration: .default)
    }

    // MARK: - getBalance

    func getBalance(publicKey: String) async throws -> UInt64 {
        let result: RPCResponse<BalanceResult> = try await rpcCall(
            method: "getBalance",
            params: [publicKey, ["commitment": "confirmed"]]
        )
        guard let value = result.result?.value else {
            throw result.error ?? RPCError(code: -1, message: "Empty balance response")
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
        let result: RPCResponse<String> = try await rpcCall(
            method: "requestAirdrop",
            params: [publicKey, lamports, ["commitment": "confirmed"]]
        )
        guard let signature = result.result else {
            throw result.error ?? RPCError(code: -1, message: "Airdrop failed")
        }
        return signature
    }

    // MARK: - getLatestBlockhash

    func getLatestBlockhash() async throws -> String {
        let result: RPCResponse<BlockhashResponse> = try await rpcCall(
            method: "getLatestBlockhash",
            params: [["commitment": "confirmed"]]
        )
        guard let blockhash = result.result?.value.blockhash else {
            throw result.error ?? RPCError(code: -1, message: "Could not fetch blockhash")
        }
        return blockhash
    }

    // MARK: - sendTransaction

    func sendTransaction(serialized: Data) async throws -> String {
        let base64Tx = serialized.base64EncodedString()
        let result: RPCResponse<String> = try await rpcCall(
            method: "sendTransaction",
            params: [base64Tx, ["encoding": "base64", "preflightCommitment": "confirmed"]]
        )
        guard let signature = result.result else {
            throw result.error ?? RPCError(code: -1, message: "sendTransaction failed")
        }
        return signature
    }

    // MARK: - getSignaturesForAddress

    func getSignaturesForAddress(publicKey: String, limit: Int = 10) async throws -> [SignatureInfo] {
        let result: RPCResponse<[SignatureInfo]> = try await rpcCall(
            method: "getSignaturesForAddress",
            params: [publicKey, ["limit": limit, "commitment": "confirmed"]]
        )
        return result.result ?? []
    }

    // MARK: - confirmTransaction (poll)

    func confirmTransaction(signature: String, maxAttempts: Int = 20) async throws -> Bool {
        for _ in 0..<maxAttempts {
            let result: RPCResponse<[SignatureStatus?]> = try await rpcCall(
                method: "getSignatureStatuses",
                params: [[signature], ["searchTransactionHistory": false]]
            )
            if let statuses = result.result, let status = statuses.first ?? nil {
                if status.confirmationStatus == "confirmed" || status.confirmationStatus == "finalized" {
                    return status.err == nil
                }
            }
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
        }
        return false
    }

    // MARK: - Private Helpers

    private func nextID() -> Int {
        requestID += 1
        return requestID
    }

    private func rpcCall<T: Decodable>(method: String, params: some Encodable) async throws -> RPCResponse<T> {
        let request = RPCRequest(id: nextID(), method: method, params: params)
        let body = try JSONEncoder().encode(request)
        var urlRequest = URLRequest(url: rpcURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RPCError(code: -32000, message: "HTTP error")
        }
        return try JSONDecoder().decode(RPCResponse<T>.self, from: data)
    }

    private func postRaw(body: [String: Any]) async throws -> Data {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        var urlRequest = URLRequest(url: rpcURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = bodyData
        let (data, _) = try await urlSession.data(for: urlRequest)
        return data
    }
}

// MARK: - getSignatureStatuses response additions

struct SignatureStatus: Decodable {
    let slot: UInt64
    let confirmations: Int?
    let err: AnyCodable?
    let confirmationStatus: String?
}

// Simple wrapper for unknown JSON values
struct AnyCodable: Decodable {}
