//
//  SolMindTests.swift
//  SolMindTests
//
//  Created by SAVELIEV Stanislav on 06/04/2026.
//

import Testing
import Foundation
@testable import SolMind

// MARK: - Base58 Tests

@Suite("Base58 Encoding")
struct Base58Tests {

    @Test func knownZeroAddress() {
        // 32 zero bytes → SystemProgram address "11111111111111111111111111111111"
        let zeros = Array(repeating: UInt8(0), count: 32)
        let encoded = Base58.encode(zeros)
        #expect(encoded == "11111111111111111111111111111111")
    }

    @Test func roundTrip() throws {
        let original: [UInt8] = [
            1, 2, 3, 4, 5, 6, 7, 8,
            9, 10, 11, 12, 13, 14, 15, 16,
            17, 18, 19, 20, 21, 22, 23, 24,
            25, 26, 27, 28, 29, 30, 31, 32
        ]
        let encoded = Base58.encode(original)
        let decoded = try #require(Base58.decode(encoded))
        #expect(decoded == original)
    }

    @Test func validAddressDetection() {
        // A known valid devnet address
        #expect(Base58.isValidAddress("11111111111111111111111111111111") == true)
        // Too short
        #expect(Base58.isValidAddress("abc") == false)
        // Invalid character (0, O, I, l are excluded from Base58 alphabet)
        #expect(Base58.isValidAddress("0InvalidCharacter") == false)
    }

    @Test func decodeInvalidStringReturnsNil() {
        #expect(Base58.decode("0OIl") == nil)
    }
}

// MARK: - Compact-U16 Tests

@Suite("Compact-U16 Encoding")
struct CompactU16Tests {

    @Test func singleByteLow() {
        #expect(TransactionBuilder.encodeCompactU16(0) == [0])
    }

    @Test func singleByteHigh() {
        #expect(TransactionBuilder.encodeCompactU16(127) == [127])
    }

    @Test func twoBytesBoundary() {
        // 128 = 0x80 → [0x80, 0x01]
        #expect(TransactionBuilder.encodeCompactU16(128) == [0x80, 0x01])
    }

    @Test func twoBytesMid() {
        // 256 = 0x100 → low 7 bits = 0, high = 2 → [0x80, 0x02]
        #expect(TransactionBuilder.encodeCompactU16(256) == [0x80, 0x02])
    }
}

// MARK: - TransactionBuilder Tests

@Suite("SOL Transfer Serialization")
struct TransactionBuilderTests {

    @Test func solTransferLength() throws {
        let sender = Keypair.generate()
        // Use a valid devnet-style recipient (SystemProgram address as stand-in)
        let recipient = "11111111111111111111111111111111"
        let blockhash = "11111111111111111111111111111111"

        let tx = try TransactionBuilder.buildSOLTransfer(
            from: sender,
            to: recipient,
            lamports: 1_000_000,
            recentBlockhash: blockhash
        )

        // Expected layout:
        //  1  byte  compact-u16 sig count (= 1)
        // 64  bytes signature
        //  3  bytes message header
        //  1  byte  compact-u16 account count (= 3)
        // 96  bytes 3 × 32-byte account keys
        // 32  bytes recent blockhash
        //  1  byte  compact-u16 instruction count (= 1)
        //  1  byte  program id index
        //  1  byte  compact-u16 account indices count (= 2)
        //  2  bytes account indices [0, 1]
        //  1  byte  compact-u16 data length (= 12)
        // 12  bytes instruction data (4-byte discriminator + 8-byte lamports)
        // Total = 1 + 64 + 3 + 1 + 96 + 32 + 1 + 1 + 1 + 2 + 1 + 12 = 215
        #expect(tx.count == 215)
    }

    @Test func solTransferSignatureBytes() throws {
        let sender = Keypair.generate()
        let recipient = "11111111111111111111111111111111"
        let blockhash = "11111111111111111111111111111111"

        let tx = try TransactionBuilder.buildSOLTransfer(
            from: sender,
            to: recipient,
            lamports: 500_000,
            recentBlockhash: blockhash
        )

        // First byte is compact-u16 count = 1
        #expect(tx[0] == 1)
        // Bytes 1-64 are the 64-byte Ed25519 signature
        // Verify the signature is non-zero (not a degenerate case)
        let sigBytes = tx[1..<65]
        #expect(sigBytes.contains(where: { $0 != 0 }))
    }

    @Test func invalidAddressThrows() {
        let sender = Keypair.generate()
        #expect(throws: TransactionError.invalidAddress) {
            try TransactionBuilder.buildSOLTransfer(
                from: sender,
                to: "not-a-valid-address!!!",
                lamports: 1,
                recentBlockhash: "11111111111111111111111111111111"
            )
        }
    }
}

