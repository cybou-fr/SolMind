import Foundation
import CryptoKit

// MARK: - Wallet Manager (multi-keypair)

@Observable
class WalletManager {
    // Currently-active keypair
    private(set) var publicKey: String?
    private var keypair: Keypair?

    // All known wallet addresses (for the picker)
    private(set) var allAddresses: [String] = []

    var isConnected: Bool { publicKey != nil }

    var displayAddress: String {
        guard let pk = publicKey else { return "Not connected" }
        return "\(pk.prefix(4))...\(pk.suffix(4))"
    }

    // MARK: - Boot

    /// Called once at app launch. Migrates legacy single-key storage, then loads the active wallet.
    func loadOrCreateWallet() throws {
        LocalWallet.migrateLegacyIfNeeded()
        allAddresses = LocalWallet.allAddresses()

        if let active = LocalWallet.activeAddress, allAddresses.contains(active) {
            try loadWallet(publicKeyBase58: active)
        } else if let first = allAddresses.first {
            try loadWallet(publicKeyBase58: first)
        } else {
            try createAndActivateWallet()
        }
    }

    // MARK: - Generate new keypair

    /// Creates a new keypair, stores it in Keychain, and makes it active.
    @discardableResult
    func createAndActivateWallet() throws -> String {
        let kp = Keypair.generate()
        let address = kp.publicKeyBase58
        try LocalWallet.save(privateKeyData: kp.privateKey.rawRepresentation, publicKeyBase58: address)
        LocalWallet.activeAddress = address
        allAddresses = LocalWallet.allAddresses()
        keypair = kp
        publicKey = address
        return address
    }

    // MARK: - Switch active wallet

    func switchWallet(to address: String) throws {
        guard allAddresses.contains(address) else { throw WalletError.invalidAddress }
        try loadWallet(publicKeyBase58: address)
        LocalWallet.activeAddress = address
    }

    // MARK: - Delete a wallet

    func deleteWallet(address: String) throws {
        try LocalWallet.delete(publicKeyBase58: address)
        allAddresses = LocalWallet.allAddresses()

        // If we deleted the active one, switch to whatever is first (or nil)
        if publicKey == address {
            if let next = allAddresses.first {
                try loadWallet(publicKeyBase58: next)
                LocalWallet.activeAddress = next
            } else {
                keypair = nil
                publicKey = nil
            }
        }
    }

    // MARK: - Internal load helper

    private func loadWallet(publicKeyBase58: String) throws {
        let rawKey = try LocalWallet.load(publicKeyBase58: publicKeyBase58)
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: rawKey)
        let kp = Keypair(privateKey: privateKey, publicKey: privateKey.publicKey)
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

    // MARK: - Reset all wallets (for testing)

    func resetAll() throws {
        for address in allAddresses {
            try? LocalWallet.delete(publicKeyBase58: address)
        }
        allAddresses = []
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

