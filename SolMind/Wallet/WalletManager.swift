import Foundation
import CryptoKit

// MARK: - Wallet Manager

@Observable
class WalletManager {
    private(set) var publicKey: String?
    private var keypair: Keypair?

    var isConnected: Bool { publicKey != nil }

    var displayAddress: String {
        guard let pk = publicKey else { return "Not connected" }
        return "\(pk.prefix(4))...\(pk.suffix(4))"
    }

    // MARK: - Load or Create

    func loadOrCreateWallet() throws {
        if LocalWallet.exists() {
            try loadWallet()
        } else {
            try createWallet()
        }
    }

    func loadWallet() throws {
        let rawKey = try LocalWallet.load()
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: rawKey)
        let kp = Keypair(privateKey: privateKey, publicKey: privateKey.publicKey)
        keypair = kp
        publicKey = kp.publicKeyBase58
    }

    func createWallet() throws {
        let kp = Keypair.generate()
        try LocalWallet.save(privateKeyData: kp.privateKey.rawRepresentation)
        keypair = kp
        publicKey = kp.publicKeyBase58
    }

    // MARK: - Signing

    func signTransaction(_ txBytes: Data) throws -> Data {
        guard let kp = keypair else { throw WalletError.notConnected }
        return try kp.sign(txBytes)
    }

    func keypairForSigning() throws -> Keypair {
        guard let kp = keypair else { throw WalletError.notConnected }
        return kp
    }

    // MARK: - Reset (for testing)

    func reset() throws {
        try LocalWallet.delete()
        keypair = nil
        publicKey = nil
    }
}

enum WalletError: LocalizedError {
    case notConnected
    case invalidAddress

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Wallet not connected."
        case .invalidAddress: return "Invalid wallet address."
        }
    }
}
