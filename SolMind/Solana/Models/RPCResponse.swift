import Foundation

// MARK: - JSON-RPC 2.0 Models

struct RPCRequest<P: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: Int
    let method: String
    let params: P
}

struct RPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int?
    let result: T?
    let error: RPCError?
}

struct RPCError: Decodable, Sendable, LocalizedError {
    let code: Int
    let message: String
    var errorDescription: String? { message }
}

// MARK: - getBalance

struct BalanceResult: Decodable, Sendable {
    let value: UInt64
}

// MARK: - getLatestBlockhash

struct BlockhashResponse: Decodable, Sendable {
    let value: BlockhashValue
}

struct BlockhashValue: Decodable, Sendable {
    let blockhash: String
    let lastValidBlockHeight: UInt64
}

// MARK: - getTokenAccountsByOwner

struct TokenAccountsResponse: Decodable, Sendable {
    let value: [TokenAccountInfo]
}

struct TokenAccountInfo: Decodable, Sendable {
    let pubkey: String
    let account: AccountData
}

struct AccountData: Decodable, Sendable {
    let data: ParsedAccountData
}

struct ParsedAccountData: Decodable, Sendable {
    let parsed: ParsedInfo
    let program: String
}

struct ParsedInfo: Decodable, Sendable {
    let info: TokenInfo
    let type: String
}

struct TokenInfo: Decodable, Sendable {
    let mint: String
    let owner: String
    let tokenAmount: TokenAmountInfo
}

struct TokenAmountInfo: Decodable, Sendable {
    let amount: String
    let decimals: Int
    let uiAmount: Double?
}

// MARK: - getSignaturesForAddress

struct SignatureInfo: Decodable, Sendable {
    let signature: String
    let slot: UInt64?
    let err: CodableNull?
    let memo: String?
    let blockTime: Int64?
}

// MARK: - Helper for nullable fields

struct CodableNull: Decodable, Sendable {}

// MARK: - getTransaction / simplified

struct TransactionDetail: Decodable, Sendable {
    let slot: UInt64
    let blockTime: Int64?
    let meta: TransactionMeta?
}

struct TransactionMeta: Decodable, Sendable {
    let fee: UInt64
    let err: CodableNull?
    var isSuccess: Bool { err == nil }
}
