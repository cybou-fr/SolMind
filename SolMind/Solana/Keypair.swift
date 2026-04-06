import Foundation
import CryptoKit

// MARK: - Ed25519 Keypair for Solana

struct Keypair {
    let privateKey: Curve25519.Signing.PrivateKey
    let publicKey: Curve25519.Signing.PublicKey

    // Solana base58 address derived from the 32-byte public key
    var publicKeyBase58: String {
        Base58.encode(Array(publicKey.rawRepresentation))
    }

    // Raw 32-byte public key
    var publicKeyBytes: [UInt8] {
        Array(publicKey.rawRepresentation)
    }

    // Generate a new random keypair
    static func generate() -> Keypair {
        let privateKey = Curve25519.Signing.PrivateKey()
        return Keypair(privateKey: privateKey, publicKey: privateKey.publicKey)
    }

    // Sign data (returns 64-byte Ed25519 signature)
    func sign(_ data: Data) throws -> Data {
        try privateKey.signature(for: data)
    }
}
