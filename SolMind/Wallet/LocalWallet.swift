import Foundation
import Security
import CryptoKit

// MARK: - Keychain Storage for Multiple Ed25519 Keypairs
//
// Each keypair is stored as a Keychain GenericPassword item:
//   kSecAttrService  = "fr.cybou.SolMind.wallet"
//   kSecAttrAccount  = base58 public key  (unique per keypair)
//   kSecValueData    = 32-byte raw private key
//
// The currently active address is tracked in UserDefaults.

struct LocalWallet {
    static let service = "fr.cybou.SolMind.wallet"
    private static let activeAddressKey = "fr.cybou.SolMind.activeWallet"

    // MARK: - Active address

    static var activeAddress: String? {
        get { UserDefaults.standard.string(forKey: activeAddressKey) }
        set { UserDefaults.standard.set(newValue, forKey: activeAddressKey) }
    }

    // MARK: - Save

    static func save(privateKeyData: Data, publicKeyBase58: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: publicKeyBase58,
            kSecValueData as String: privateKeyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Load single

    static func load(publicKeyBase58: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: publicKeyBase58,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.notFound
        }
        return data
    }

    // MARK: - List all stored addresses

    static func allAddresses() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    // MARK: - Delete single

    static func delete(publicKeyBase58: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: publicKeyBase58
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
        if activeAddress == publicKeyBase58 {
            activeAddress = allAddresses().first
        }
    }

    // MARK: - Export private key

    /// Returns the wallet's private key as a base58-encoded 64-byte array
    /// (32-byte seed ‖ 32-byte public key), compatible with Phantom and Solflare import.
    static func exportPrivateKeyBase58(address publicKeyBase58: String) throws -> String {
        let seedData = try load(publicKeyBase58: publicKeyBase58)
        guard let privateKey = try? CryptoKit.Curve25519.Signing.PrivateKey(rawRepresentation: seedData)
        else { throw KeychainError.notFound }
        var keyBytes = Array(seedData)
        keyBytes.append(contentsOf: privateKey.publicKey.rawRepresentation)
        return Base58.encode(keyBytes)
    }

    // MARK: - Existence check (any wallet)

    static func hasAnyWallet() -> Bool {
        !allAddresses().isEmpty
    }

    // MARK: - Legacy migration (single-key account → multi-key)
    //
    // Old items used account = "ed25519-private-key". On first launch after update,
    // migrate them under the real public key so they participate in the multi-wallet flow.

    static func migrateLegacyIfNeeded() {
        let legacyAccount = "ed25519-private-key"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let rawKey = result as? Data,
              let privateKey = try? CryptoKit.Curve25519.Signing.PrivateKey(rawRepresentation: rawKey) else { return }

        let publicKeyBase58 = Base58.encode(Array(privateKey.publicKey.rawRepresentation))
        try? save(privateKeyData: rawKey, publicKeyBase58: publicKeyBase58)
        if activeAddress == nil { activeAddress = publicKeyBase58 }

        // Remove old item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case notFound
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let s): return "Keychain save failed (OSStatus \(s))"
        case .notFound: return "No wallet found in Keychain."
        case .deleteFailed(let s): return "Keychain delete failed (OSStatus \(s))"
        }
    }
}

