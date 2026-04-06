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

struct RPCError: Decodable, LocalizedError {
    let code: Int
    let message: String
    var errorDescription: String? { message }
}

// MARK: - getBalance

struct BalanceResult: Decodable {
    let value: UInt64
}

// MARK: - getLatestBlockhash

struct BlockhashResponse: Decodable {
    let value: BlockhashValue
}

struct BlockhashValue: Decodable {
    let blockhash: String
    let lastValidBlockHeight: UInt64
}

// MARK: - getTokenAccountsByOwner

struct TokenAccountsResponse: Decodable {
    let value: [TokenAccountInfo]
}

struct TokenAccountInfo: Decodable {
    let pubkey: String
    let account: AccountData
}

struct AccountData: Decodable {
    let data: ParsedAccountData
}

struct ParsedAccountData: Decodable {
    let parsed: ParsedInfo
    let program: String
}

struct ParsedInfo: Decodable {
    let info: TokenInfo
    let type: String
}

struct TokenInfo: Decodable {
    let mint: String
    let owner: String
    let tokenAmount: TokenAmountInfo
}

struct TokenAmountInfo: Decodable {
    let amount: String
    let decimals: Int
    let uiAmount: Double?
}

// MARK: - getSignaturesForAddress

struct SignatureInfo: Decodable {
    let signature: String
    let slot: UInt64?
    let err: CodableNull?
    let memo: String?
    let blockTime: Int64?
}

// MARK: - Helper for nullable fields

struct CodableNull: Decodable {}

// MARK: - getTransaction / simplified

struct TransactionDetail: Decodable {
    let slot: UInt64
    let blockTime: Int64?
    let meta: TransactionMeta?
}

struct TransactionMeta: Decodable {
    let fee: UInt64
    let err: CodableNull?
    var isSuccess: Bool { err == nil }
}
