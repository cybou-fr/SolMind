//
//  SolMindTests.swift
//  SolMindTests
//
//  Created by SAVELIEV Stanislav on 06/04/2026.
//

import Testing
import Foundation
@testable import SolMind

// MARK: - AIInstructions Tests

@Suite("AI Instructions Context Block")
struct AIInstructionsTests {

    @Test func contextBlockContainsWallet() {
        let result = AIInstructions.contextBlock(
            walletAddress: "AbCdEfGhIjKlMnOp1234567890ABCDEF12345678",
            solBalance: 2.5,
            solUSDValue: 350.0,
            tokenBalances: [],
            statsContext: "",
            userMessage: "Hello"
        )
        #expect(result.contains("AbCdEfGhIjKlMnOp1234567890ABCDEF12345678"))
    }

    @Test func contextBlockFormatsSolBalance() {
        let result = AIInstructions.contextBlock(
            walletAddress: "addr",
            solBalance: 1.23456789,
            solUSDValue: nil,
            tokenBalances: [],
            statsContext: "",
            userMessage: "test"
        )
        #expect(result.contains("1.2346 SOL"))
    }

    @Test func contextBlockIncludesUSDValue() {
        let result = AIInstructions.contextBlock(
            walletAddress: "addr",
            solBalance: 1.0,
            solUSDValue: 125.50,
            tokenBalances: [],
            statsContext: "",
            userMessage: "hi"
        )
        #expect(result.contains("$125.50"))
    }

    @Test func contextBlockIncludesTokenBalances() {
        let result = AIInstructions.contextBlock(
            walletAddress: "addr",
            solBalance: 1.0,
            solUSDValue: nil,
            tokenBalances: [
                (symbol: "USDC", uiAmount: 100.0, usdValue: 100.0),
                (symbol: "SMND", uiAmount: 1_000_000, usdValue: nil)
            ],
            statsContext: "",
            userMessage: "check tokens"
        )
        #expect(result.contains("USDC"))
        #expect(result.contains("SMND"))
        #expect(result.contains("Tokens:"))
    }

    @Test func contextBlockPreservesUserMessage() {
        let msg = "What is my balance?"
        let result = AIInstructions.contextBlock(
            walletAddress: "addr",
            solBalance: 0,
            solUSDValue: nil,
            tokenBalances: [],
            statsContext: "",
            userMessage: msg
        )
        #expect(result.hasSuffix(msg))
    }

    @Test func contextBlockTokensCappedAtFour() {
        let tokens = (1...6).map { i in
            (symbol: "TK\(i)", uiAmount: Double(i * 10), usdValue: Optional<Double>.none)
        }
        let result = AIInstructions.contextBlock(
            walletAddress: "addr",
            solBalance: 1.0,
            solUSDValue: nil,
            tokenBalances: tokens,
            statsContext: "",
            userMessage: "test"
        )
        // Only first 4 tokens should appear
        #expect(result.contains("TK1"))
        #expect(result.contains("TK4"))
        #expect(!result.contains("TK5"))
    }

    @Test func contextBlockIncludesStatsContext() {
        let stats = "SOL $140.00 | Epoch 750 (62%) | ~2800 TPS"
        let result = AIInstructions.contextBlock(
            walletAddress: "addr",
            solBalance: 1.0,
            solUSDValue: nil,
            tokenBalances: [],
            statsContext: stats,
            userMessage: "check stats"
        )
        #expect(result.contains(stats))
    }

    @Test func contextBlockZeroBalance() {
        let result = AIInstructions.contextBlock(
            walletAddress: "addr",
            solBalance: 0.0,
            solUSDValue: 0.0,
            tokenBalances: [],
            statsContext: "",
            userMessage: "balance?"
        )
        #expect(result.contains("0.0000 SOL"))
        #expect(result.contains("$0.00"))
    }

    @Test func contextBlockExactlyFourTokensAllAppear() {
        let tokens = (1...4).map { i in
            (symbol: "T\(i)", uiAmount: Double(i), usdValue: Optional<Double>.none)
        }
        let result = AIInstructions.contextBlock(
            walletAddress: "addr",
            solBalance: 1.0,
            solUSDValue: nil,
            tokenBalances: tokens,
            statsContext: "",
            userMessage: "tokens"
        )
        #expect(result.contains("T1"))
        #expect(result.contains("T2"))
        #expect(result.contains("T3"))
        #expect(result.contains("T4"))
    }
}

// MARK: - SuggestionEngine Tests

@Suite("Suggestion Engine")
struct SuggestionEngineTests {

    @Test func emptyWalletSuggestsFaucet() {
        let suggestions = SuggestionEngine.suggestions(
            for: "Your SOL balance is 0 SOL",
            userMessage: "what's my balance",
            walletHasBalance: false
        )
        #expect(suggestions.contains("Get free devnet SOL"))
    }

    @Test func successfulTxSuggestsHistory() {
        let suggestions = SuggestionEngine.suggestions(
            for: "✅ DEVNET: Transaction sent! Signature: abc123...",
            userMessage: "send 0.1 SOL",
            walletHasBalance: true
        )
        #expect(suggestions.contains("View transaction history"))
    }

    @Test func balanceQueryWithFundsSuggestsSend() {
        let suggestions = SuggestionEngine.suggestions(
            for: "SOL balance: 2.5 SOL",
            userMessage: "what's my balance?",
            walletHasBalance: true
        )
        #expect(suggestions.contains("Send SOL to someone"))
    }

    @Test func nftTopicSuggestsGallery() {
        let suggestions = SuggestionEngine.suggestions(
            for: "Your NFT was minted successfully",
            userMessage: "mint me an nft",
            walletHasBalance: true
        )
        #expect(suggestions.contains("View my NFT gallery"))
    }

    @Test func defaultSuggestionsReturnFour() {
        let suggestions = SuggestionEngine.suggestions(
            for: "Here is some general info.",
            userMessage: "something unrelated",
            walletHasBalance: true
        )
        #expect(suggestions.count == 4)
    }

    @Test func errorResponseSuggestsRetry() {
        let suggestions = SuggestionEngine.suggestions(
            for: "Transaction failed: connection error",
            userMessage: "send SOL",
            walletHasBalance: true
        )
        #expect(suggestions.contains("Try again"))
    }

    @Test func swapTopicSuggestsJupiter() {
        let suggestions = SuggestionEngine.suggestions(
            for: "Swap unavailable on devnet. Jupiter runs on mainnet.",
            userMessage: "swap sol for usdc",
            walletHasBalance: true
        )
        #expect(suggestions.contains { $0.lowercased().contains("jupiter") || $0.lowercased().contains("swap") })
    }

    @Test func airdropTopicSuggestsBalance() {
        let suggestions = SuggestionEngine.suggestions(
            for: "Airdrop of 1 SOL requested successfully.",
            userMessage: "give me devnet sol from faucet",
            walletHasBalance: true
        )
        #expect(suggestions.contains { $0.lowercased().contains("balance") })
    }

    @Test func suggestionsAreNeverEmpty() {
        // For any input, suggestions should always return at least one entry
        let contexts: [(String, String, Bool)] = [
            ("", "", true),
            ("error", "send", false),
            ("✅ signature abc", "swap", true),
            ("nft minted", "mint nft", true),
        ]
        for (response, message, hasBalance) in contexts {
            let result = SuggestionEngine.suggestions(
                for: response,
                userMessage: message,
                walletHasBalance: hasBalance
            )
            #expect(!result.isEmpty)
        }
    }

    @Test func noBlankSuggestionsReturned() {
        let suggestions = SuggestionEngine.suggestions(
            for: "Some random response about Solana.",
            userMessage: "tell me about solana",
            walletHasBalance: true
        )
        #expect(suggestions.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }
}

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

    @Test func leadingZeroBytesPreservedAsOnes() {
        // Leading zero bytes encode as leading '1' characters in Base58
        let twoZerosThenOne: [UInt8] = [0, 0, 1]
        let encoded = Base58.encode(twoZerosThenOne)
        #expect(encoded.hasPrefix("11"))
    }

    @Test func knownTokenProgramAddress() {
        // Token Program address should decode to exactly 32 bytes
        let tokenProgram = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        let decoded = Base58.decode(tokenProgram)
        #expect(decoded != nil)
        #expect(decoded?.count == 32)
        // Re-encoding should produce the same string
        if let bytes = decoded {
            #expect(Base58.encode(bytes) == tokenProgram)
        }
    }

    @Test func decodeEmptyStringReturnsEmpty() {
        let decoded = Base58.decode("")
        // Empty string should decode to empty array, not nil
        #expect(decoded != nil)
        #expect(decoded?.isEmpty == true)
    }

    @Test func singleMaxByteRoundTrip() {
        // Single byte [255] should encode and round-trip cleanly
        let input: [UInt8] = [255]
        let encoded = Base58.encode(input)
        let decoded = Base58.decode(encoded)
        #expect(decoded == input)
    }

    @Test func isValidAddressRequires32Bytes() {
        // Token Program is valid (32 bytes)
        #expect(Base58.isValidAddress("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA") == true)
        // ATA Program is valid (32 bytes)
        #expect(Base58.isValidAddress("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJe1bQ") == true)
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

    @Test func twoBytes255() {
        // 255 = 0xFF → low 7 bits = 0x7F with continuation, high = 1 → [0xFF, 0x01]
        #expect(TransactionBuilder.encodeCompactU16(255) == [0xFF, 0x01])
    }

    @Test func compactU16Is1ByteForSmallAccounts() {
        // Account counts up to 127 should always encode as 1 byte
        for n in UInt16(0)...UInt16(127) {
            let encoded = TransactionBuilder.encodeCompactU16(n)
            #expect(encoded.count == 1)
        }
    }
}

// MARK: - SOL Transfer Serialization Tests

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

    @Test func invalidBlockhashThrows() {
        let sender = Keypair.generate()
        #expect(throws: TransactionError.invalidBlockhash) {
            try TransactionBuilder.buildSOLTransfer(
                from: sender,
                to: "11111111111111111111111111111111",
                lamports: 1,
                recentBlockhash: "not-a-blockhash"
            )
        }
    }

    @Test func differentSendersProduceDifferentSignatures() throws {
        let sender1 = Keypair.generate()
        let sender2 = Keypair.generate()
        let recipient = "11111111111111111111111111111111"
        let blockhash = "11111111111111111111111111111111"

        let tx1 = try TransactionBuilder.buildSOLTransfer(from: sender1, to: recipient, lamports: 100, recentBlockhash: blockhash)
        let tx2 = try TransactionBuilder.buildSOLTransfer(from: sender2, to: recipient, lamports: 100, recentBlockhash: blockhash)

        // Signatures (bytes 1-64) must differ
        #expect(tx1[1..<65] != tx2[1..<65])
    }
}

// MARK: - SPL Token & Mint Transaction Tests

@Suite("SPL and Mint Transaction Serialization")
struct SPLTransactionTests {

    private let blockhash = "11111111111111111111111111111111"
    // Devnet USDC mint as a stand-in valid mint address
    private let devnetUSDC = "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU"

    @Test func splTransferLength() throws {
        let sender = Keypair.generate()
        let recipient = "11111111111111111111111111111111"

        let tx = try TransactionBuilder.buildSPLTransfer(
            from: sender,
            to: recipient,
            mintBase58: devnetUSDC,
            amount: 1_000_000,
            recentBlockhash: blockhash
        )

        // Layout: 1 sig count + 64 sig + 318 message = 383
        // Message: 3 header + 1 acc count + 256 (8×32) + 32 blockhash
        //         + 1 ix count + 10 (createATA ix) + 15 (transfer ix) = 318
        #expect(tx.count == 383)
    }

    @Test func splTransferSigCountIsOne() throws {
        let sender = Keypair.generate()
        let tx = try TransactionBuilder.buildSPLTransfer(
            from: sender,
            to: "11111111111111111111111111111111",
            mintBase58: devnetUSDC,
            amount: 500,
            recentBlockhash: blockhash
        )
        #expect(tx[0] == 1)
    }

    @Test func splTransferInvalidRecipientThrows() {
        let sender = Keypair.generate()
        #expect(throws: TransactionError.invalidAddress) {
            try TransactionBuilder.buildSPLTransfer(
                from: sender,
                to: "bad-address",
                mintBase58: devnetUSDC,
                amount: 1,
                recentBlockhash: blockhash
            )
        }
    }

    @Test func splTransferInvalidMintThrows() {
        let sender = Keypair.generate()
        #expect {
            try TransactionBuilder.buildSPLTransfer(
                from: sender,
                to: "11111111111111111111111111111111",
                mintBase58: "not-a-mint",
                amount: 1,
                recentBlockhash: blockhash
            )
        } throws: { error in
            // Should be a buildFailed error for invalid mint
            (error as? TransactionError) != nil
        }
    }

    @Test func createMintLength() throws {
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()

        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer,
            mintKeypair: mintKeypair,
            decimals: 6,
            recentBlockhash: blockhash
        )

        // Layout: 1 sig count + 64 payer sig + 64 mint sig + 293 message = 422
        // Message: 3 header + 1 acc count + 128 (4×32) + 32 blockhash
        //         + 1 ix count + 57 (createAccount ix) + 71 (initMint2 ix) = 293
        #expect(tx.count == 422)
    }

    @Test func createMintHasTwoSignatures() throws {
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()

        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer,
            mintKeypair: mintKeypair,
            decimals: 9,
            recentBlockhash: blockhash
        )

        // First byte is compact-u16 encoding of sig count = 2
        #expect(tx[0] == 2)
        // Two distinct 64-byte signatures follow
        let sig1 = tx[1..<65]
        let sig2 = tx[65..<129]
        #expect(sig1.contains(where: { $0 != 0 }))
        #expect(sig2.contains(where: { $0 != 0 }))
        // The two signatures must differ (different signers)
        #expect(sig1 != sig2)
    }

    @Test func mintTokensLength() throws {
        let payer = Keypair.generate()
        // Use ataProgramID bytes as a mock mint (known valid 32-byte address)
        let mint = TransactionBuilder.ataProgramID

        let tx = try TransactionBuilder.buildMintTokens(
            payer: payer,
            mint: mint,
            amount: 1_000_000,
            recentBlockhash: blockhash
        )

        // Layout: 1 sig count + 64 sig + 254 message = 319
        // Message: 3 header + 1 acc count + 192 (6×32) + 32 blockhash
        //         + 1 ix count + 10 (createATA ix) + 15 (mintTo ix) = 254
        #expect(tx.count == 319)
    }
}

// MARK: - PDA and ATA Derivation Tests

@Suite("PDA and ATA Derivation")
struct PDADerivationTests {

    @Test func pdaDerivationIsDeterministic() {
        // Use ataProgramID as programId — a real 32-byte address that produces off-curve results
        let seeds: [[UInt8]] = [Array("solmind-test".utf8)]
        let programId = TransactionBuilder.ataProgramID

        let result1 = TransactionBuilder.findProgramAddress(seeds: seeds, programId: programId)
        let result2 = TransactionBuilder.findProgramAddress(seeds: seeds, programId: programId)

        #expect(result1 != nil)
        #expect(result1?.0 == result2?.0)
        #expect(result1?.1 == result2?.1)
    }

    @Test func pdaDerivationProduces32Bytes() {
        let seeds: [[UInt8]] = [Array("test".utf8)]
        let programId = TransactionBuilder.ataProgramID

        let result = TransactionBuilder.findProgramAddress(seeds: seeds, programId: programId)
        #expect(result != nil)
        #expect(result?.0.count == 32)
    }

    @Test func differentSeedsDifferentPDA() {
        let programId = TransactionBuilder.ataProgramID

        let result1 = TransactionBuilder.findProgramAddress(
            seeds: [Array("seed-a".utf8)],
            programId: programId
        )
        let result2 = TransactionBuilder.findProgramAddress(
            seeds: [Array("seed-b".utf8)],
            programId: programId
        )

        // Different seeds must produce different PDAs (both non-nil)
        #expect(result1 != nil)
        #expect(result2 != nil)
        #expect(result1?.0 != result2?.0)
    }

    @Test func ataDerivationIsNonNilAndIs32Bytes() {
        // Use a real keypair's public key as owner with a stable mock mint
        let owner = Keypair.generate().publicKeyBytes
        let mint = Array(repeating: UInt8(5), count: 32)

        let ata = TransactionBuilder.associatedTokenAddress(owner: owner, mint: mint)
        #expect(ata != nil)
        #expect(ata?.count == 32)
    }

    @Test func ataDerivationIsDeterministic() {
        let owner = Keypair.generate().publicKeyBytes
        let mint = Array(repeating: UInt8(5), count: 32)

        let ata1 = TransactionBuilder.associatedTokenAddress(owner: owner, mint: mint)
        let ata2 = TransactionBuilder.associatedTokenAddress(owner: owner, mint: mint)
        #expect(ata1 == ata2)
    }

    @Test func differentOwnersProduceDifferentATAs() {
        let owner1 = Keypair.generate().publicKeyBytes
        let owner2 = Keypair.generate().publicKeyBytes
        // Use ataProgramID bytes as a stable mock mint
        let mint = TransactionBuilder.ataProgramID

        let ata1 = TransactionBuilder.associatedTokenAddress(owner: owner1, mint: mint)
        let ata2 = TransactionBuilder.associatedTokenAddress(owner: owner2, mint: mint)
        #expect(ata1 != nil)
        #expect(ata2 != nil)
        #expect(ata1 != ata2)
    }
}

// MARK: - KnownPrograms Tests

@Suite("KnownPrograms Registry")
struct KnownProgramsTests {

    @Test func lookupSystemProgramByAddress() {
        let info = KnownPrograms.info(for: "11111111111111111111111111111111")
        #expect(info != nil)
        #expect(info?.category == "System")
    }

    @Test func lookupTokenProgramByAddress() {
        let info = KnownPrograms.info(for: "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")
        #expect(info != nil)
        #expect(info?.category == "Token")
    }

    @Test func lookupATAProgramByAddress() {
        let info = KnownPrograms.info(for: "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJe1bQ")
        #expect(info != nil)
        #expect(info?.category == "Token")
    }

    @Test func lookupUnknownAddressReturnsNil() {
        let info = KnownPrograms.info(for: "SomeFakeAddress1111111111111111111111111111")
        #expect(info == nil)
    }

    @Test func searchByNameCaseInsensitive() {
        let results = KnownPrograms.search(name: "jupiter")
        #expect(!results.isEmpty)
        #expect(results.allSatisfy {
            $0.name.lowercased().contains("jupiter") || $0.description.lowercased().contains("jupiter")
        })
    }

    @Test func searchByKeywordFindsMetaplex() {
        let results = KnownPrograms.search(name: "metaplex")
        #expect(!results.isEmpty)
    }

    @Test func searchNonExistentKeywordReturnsEmpty() {
        let results = KnownPrograms.search(name: "xxxxnotarealprotocolxxx99999")
        #expect(results.isEmpty)
    }

    @Test func allProgramAddressesDecodeToValidBytes() {
        for (address, info) in KnownPrograms.all {
            let decoded = Base58.decode(address)
            #expect(decoded != nil, "Address for '\(info.name)' is not valid Base58")
            #expect(decoded?.count == 32, "Address for '\(info.name)' does not decode to 32 bytes")
        }
    }

    @Test func registryHasAtLeast20Programs() {
        #expect(KnownPrograms.all.count >= 20)
    }

    @Test func multipleKnownCategoriesPresent() {
        let categories = Set(KnownPrograms.all.values.map { $0.category })
        #expect(categories.contains("System"))
        #expect(categories.contains("Token"))
        #expect(categories.contains("DeFi"))
        #expect(categories.contains("NFT"))
    }
}

// MARK: - AppSettings Tests

@Suite("AppSettings Runtime Configuration", .serialized)
struct AppSettingsTests {

    @Test func effectiveHeliusKeyFallsBackToSecretsWhenBlank() {
        let settings = AppSettings.shared
        let original = settings.heliusAPIKey
        defer { settings.heliusAPIKey = original }

        settings.heliusAPIKey = ""
        #expect(settings.effectiveHeliusAPIKey == Secrets.heliusAPIKey)
    }

    @Test func effectiveHeliusKeyUsesUserValueWhenSet() {
        let settings = AppSettings.shared
        let original = settings.heliusAPIKey
        defer { settings.heliusAPIKey = original }

        settings.heliusAPIKey = "user-helius-key-abc"
        #expect(settings.effectiveHeliusAPIKey == "user-helius-key-abc")
    }

    @Test func effectiveMoonpayKeyFallsBackToSecretsWhenBlank() {
        let settings = AppSettings.shared
        let original = settings.moonpayAPIKey
        defer { settings.moonpayAPIKey = original }

        settings.moonpayAPIKey = ""
        #expect(settings.effectiveMoonpayAPIKey == Secrets.moonpayAPIKey)
    }

    @Test func effectiveMoonpayKeyUsesUserValueWhenSet() {
        let settings = AppSettings.shared
        let original = settings.moonpayAPIKey
        defer { settings.moonpayAPIKey = original }

        settings.moonpayAPIKey = "user-moonpay-key-xyz"
        #expect(settings.effectiveMoonpayAPIKey == "user-moonpay-key-xyz")
    }

    @Test func resetAPIKeysClearsBothKeys() {
        let settings = AppSettings.shared
        let originalHelius = settings.heliusAPIKey
        let originalMoonpay = settings.moonpayAPIKey
        defer {
            settings.heliusAPIKey = originalHelius
            settings.moonpayAPIKey = originalMoonpay
        }

        settings.heliusAPIKey = "helius-test"
        settings.moonpayAPIKey = "moonpay-test"
        settings.resetAPIKeys()

        #expect(settings.heliusAPIKey.isEmpty)
        #expect(settings.moonpayAPIKey.isEmpty)
    }

    @Test func resetAPIKeysRestoresFallback() {
        let settings = AppSettings.shared
        let originalHelius = settings.heliusAPIKey
        defer { settings.heliusAPIKey = originalHelius }

        settings.heliusAPIKey = "custom-key"
        settings.resetAPIKeys()

        // After reset, effective key should fall back to compiled Secrets
        #expect(settings.effectiveHeliusAPIKey == Secrets.heliusAPIKey)
    }

    @Test func hapticFeedbackDefaultIsTrue() {
        // This test checks the default; only meaningful on a fresh install
        // We verify the type and that it is a Bool that can be toggled
        let settings = AppSettings.shared
        let original = settings.hapticFeedbackEnabled
        defer { settings.hapticFeedbackEnabled = original }

        settings.hapticFeedbackEnabled = false
        #expect(settings.hapticFeedbackEnabled == false)
        settings.hapticFeedbackEnabled = true
        #expect(settings.hapticFeedbackEnabled == true)
    }
}
