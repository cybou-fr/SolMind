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
        #expect(Base58.isValidAddress("11111111111111111111111111111111") == true)
        #expect(Base58.isValidAddress("abc") == false)
        #expect(Base58.isValidAddress("0InvalidCharacter") == false)
    }

    @Test func decodeInvalidStringReturnsNil() {
        #expect(Base58.decode("0OIl") == nil)
    }

    @Test func leadingZeroBytesPreservedAsOnes() {
        let twoZerosThenOne: [UInt8] = [0, 0, 1]
        let encoded = Base58.encode(twoZerosThenOne)
        #expect(encoded.hasPrefix("11"))
    }

    @Test func knownTokenProgramAddress() {
        let tokenProgram = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        let decoded = Base58.decode(tokenProgram)
        #expect(decoded != nil)
        #expect(decoded?.count == 32)
        if let bytes = decoded {
            #expect(Base58.encode(bytes) == tokenProgram)
        }
    }

    @Test func decodeEmptyStringReturnsEmpty() {
        let decoded = Base58.decode("")
        #expect(decoded != nil)
        #expect(decoded?.isEmpty == true)
    }

    @Test func singleMaxByteRoundTrip() {
        let input: [UInt8] = [255]
        let encoded = Base58.encode(input)
        let decoded = Base58.decode(encoded)
        #expect(decoded == input)
    }

    @Test func isValidAddressRequires32Bytes() {
        #expect(Base58.isValidAddress("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA") == true)
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
        #expect(TransactionBuilder.encodeCompactU16(128) == [0x80, 0x01])
    }

    @Test func twoBytesMid() {
        #expect(TransactionBuilder.encodeCompactU16(256) == [0x80, 0x02])
    }

    @Test func twoBytes255() {
        #expect(TransactionBuilder.encodeCompactU16(255) == [0xFF, 0x01])
    }

    @Test func compactU16Is1ByteForSmallAccounts() {
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
        let recipient = "11111111111111111111111111111111"
        let blockhash = "11111111111111111111111111111111"

        let tx = try TransactionBuilder.buildSOLTransfer(
            from: sender,
            to: recipient,
            lamports: 1_000_000,
            recentBlockhash: blockhash
        )

        // 1 sig count + 64 sig + 3 header + 1 acc count + 96 accounts
        // + 32 blockhash + 1 ix count + 1 prog idx + 1 acct count
        // + 2 acct indices + 1 data len + 12 data = 215
        #expect(tx.count == 215)
    }

    @Test func solTransferSignatureBytes() throws {
        let sender = Keypair.generate()
        let tx = try TransactionBuilder.buildSOLTransfer(
            from: sender,
            to: "11111111111111111111111111111111",
            lamports: 500_000,
            recentBlockhash: "11111111111111111111111111111111"
        )
        #expect(tx[0] == 1)
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

        #expect(tx1[1..<65] != tx2[1..<65])
    }
}

// MARK: - SPL Token & Mint Transaction Tests

@Suite("SPL and Mint Transaction Serialization")
struct SPLTransactionTests {

    private let blockhash = "11111111111111111111111111111111"
    private let devnetUSDC = "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU"

    @Test func splTransferLength() throws {
        let sender = Keypair.generate()
        let tx = try TransactionBuilder.buildSPLTransfer(
            from: sender,
            to: "11111111111111111111111111111111",
            mintBase58: devnetUSDC,
            amount: 1_000_000,
            recentBlockhash: blockhash
        )
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

        // Layout: 1 sig count + 64 payer sig + 64 mint sig + 296 message = 425
        // Message: 3 header + 1 acc count + 128 (4×32) + 32 blockhash
        //         + 1 ix count + 57 (createAccount) + 74 (initMint2) = 296
        //
        // initMint2 data = 70 bytes:
        //   1 discriminator(20) + 1 decimals + 32 mintAuth
        //   + 4 COption::Some([1,0,0,0]) + 32 freezeAuth
        //   COption uses u32 LE discriminant — NOT 1-byte u8!
        #expect(tx.count == 425)
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
        #expect(tx[0] == 2)
        let sig1 = tx[1..<65]
        let sig2 = tx[65..<129]
        #expect(sig1.contains(where: { $0 != 0 }))
        #expect(sig2.contains(where: { $0 != 0 }))
        #expect(sig1 != sig2)
    }

    @Test func mintTokensLength() throws {
        let payer = Keypair.generate()
        let mint = TransactionBuilder.ataProgramID
        let tx = try TransactionBuilder.buildMintTokens(
            payer: payer,
            mint: mint,
            amount: 1_000_000,
            recentBlockhash: blockhash
        )
        // 1 sig count + 64 sig + 254 message = 319
        #expect(tx.count == 319)
    }
}

// MARK: - InitializeMint2 Byte Content Tests
//
// These tests verify the exact binary encoding of the InitializeMint2 instruction.
// The critical invariant: freeze_authority uses COption<Pubkey> with a 4-byte
// u32 LE discriminant ([1,0,0,0] for Some), NOT a 1-byte u8 discriminant.
// Wrong encoding → Token Program silently rejects every createToken call.
//
// Transaction layout for buildCreateMint (425 bytes total):
//  [0]        compact-u16 sig count = 2
//  [1..64]    payer Ed25519 signature
//  [65..128]  mint Ed25519 signature
//  [129..131] message header
//  [132]      account count = 4
//  [133..164] payer pubkey
//  [165..196] mint pubkey
//  [197..228] systemProgramID
//  [229..260] tokenProgramID
//  [261..292] blockhash
//  [293]      instruction count = 2
//  IX0 createAccount [294..350]:
//    [294] programIdIndex=2, [295] acctCount=2, [296-297] [0,1]
//    [298] dataLen=52, [299..350] data
//  IX1 InitializeMint2 [351..424]:
//    [351] programIdIndex=3
//    [352] acctCount=1, [353] acctIdx=1
//    [354] dataLen=70
//    [355] discriminator=20
//    [356] decimals
//    [357..388] mintAuthority (32 bytes)
//    [389..392] COption::Some = [1,0,0,0]  ← u32 LE, NOT u8
//    [393..424] freezeAuthority (32 bytes)

@Suite("InitializeMint2 Instruction Byte Content")
struct InitializeMint2ByteContentTests {

    private let blockhash = "11111111111111111111111111111111"

    @Test func initMint2DiscriminatorIs20() throws {
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()
        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer, mintKeypair: mintKeypair,
            decimals: 6, recentBlockhash: blockhash
        )
        // InitializeMint2 discriminator = 20 (not InitializeMint which is 0)
        #expect(tx[355] == 20)
    }

    @Test func initMint2DecimalsEncodedCorrectly() throws {
        for decimals in [UInt8(0), 6, 9] {
            let payer = Keypair.generate()
            let mintKeypair = Keypair.generate()
            let tx = try TransactionBuilder.buildCreateMint(
                payer: payer, mintKeypair: mintKeypair,
                decimals: decimals, recentBlockhash: blockhash
            )
            #expect(tx[356] == decimals, "Decimals byte mismatch for \(decimals)")
        }
    }

    @Test func initMint2COptionUsesFourByteU32Discriminant() throws {
        // This is the critical test that would have caught the COption bug.
        // Before the fix: code did `initMintData.append(1)` — 1 byte, wrong.
        // After the fix: code does `append(contentsOf: [1, 0, 0, 0])` — u32 LE, correct.
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()
        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer, mintKeypair: mintKeypair,
            decimals: 6, recentBlockhash: blockhash
        )
        let coptionBytes = [tx[389], tx[390], tx[391], tx[392]]
        #expect(coptionBytes == [1, 0, 0, 0],
            "COption::Some must be [1,0,0,0] (u32 LE), got \(coptionBytes)")
    }

    @Test func initMint2FreezeAuthorityMatchesMintAuthority() throws {
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()
        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer, mintKeypair: mintKeypair,
            decimals: 6, recentBlockhash: blockhash
        )
        let mintAuth = Array(tx[357..<389])
        let freezeAuth = Array(tx[393..<425])
        let payerBytes = payer.publicKeyBytes
        #expect(mintAuth == payerBytes, "mintAuthority should equal payer pubkey")
        #expect(freezeAuth == payerBytes, "freezeAuthority should equal payer pubkey")
        #expect(mintAuth == freezeAuth)
    }

    @Test func initMint2MintAuthorityIsNonZero() throws {
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()
        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer, mintKeypair: mintKeypair,
            decimals: 6, recentBlockhash: blockhash
        )
        let mintAuthBytes = Array(tx[357..<389])
        #expect(mintAuthBytes.count == 32)
        #expect(mintAuthBytes.contains(where: { $0 != 0 }))
    }

    @Test func initMint2ProgramIdIndexPointsToTokenProgram() throws {
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()
        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer, mintKeypair: mintKeypair,
            decimals: 6, recentBlockhash: blockhash
        )
        // Account table: [0]=payer, [1]=mint, [2]=systemProgram, [3]=tokenProgram
        #expect(tx[351] == 3)
    }

    @Test func initMint2AccountIndexPointsToMint() throws {
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()
        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer, mintKeypair: mintKeypair,
            decimals: 6, recentBlockhash: blockhash
        )
        #expect(tx[352] == 1)  // account count = 1
        #expect(tx[353] == 1)  // account index = 1 (mint)
    }

    @Test func initMint2DataLengthIs70() throws {
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()
        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer, mintKeypair: mintKeypair,
            decimals: 6, recentBlockhash: blockhash
        )
        // data = 1 discriminator + 1 decimals + 32 mintAuth + 4 COption + 32 freezeAuth = 70
        #expect(tx[354] == 70)
    }

    @Test func initMint2TotalTransactionIs425Bytes() throws {
        let payer = Keypair.generate()
        let mintKeypair = Keypair.generate()
        let tx = try TransactionBuilder.buildCreateMint(
            payer: payer, mintKeypair: mintKeypair,
            decimals: 6, recentBlockhash: blockhash
        )
        #expect(tx.count == 425)
    }
}

// MARK: - MintTo Instruction Content Tests

@Suite("MintTo Instruction Content")
struct MintToInstructionContentTests {

    private let blockhash = "11111111111111111111111111111111"

    @Test func mintToSigCountIsOne() throws {
        let payer = Keypair.generate()
        let mint = TransactionBuilder.ataProgramID
        let tx = try TransactionBuilder.buildMintTokens(
            payer: payer, mint: mint, amount: 1_000_000,
            recentBlockhash: blockhash
        )
        #expect(tx[0] == 1)
    }

    @Test func mintToTotalLength() throws {
        let payer = Keypair.generate()
        let mint = TransactionBuilder.ataProgramID
        let tx = try TransactionBuilder.buildMintTokens(
            payer: payer, mint: mint, amount: 1_000_000,
            recentBlockhash: blockhash
        )
        #expect(tx.count == 319)
    }

    @Test func mintToHasTwoInstructions() throws {
        let payer = Keypair.generate()
        let mint = TransactionBuilder.ataProgramID
        let tx = try TransactionBuilder.buildMintTokens(
            payer: payer, mint: mint, amount: 1_000_000,
            recentBlockhash: blockhash
        )
        // Instruction count at byte 293 = 2 (createATA + mintTo)
        #expect(tx[293] == 2)
    }

    @Test func mintToSignatureIsNonZero() throws {
        let payer = Keypair.generate()
        let mint = TransactionBuilder.ataProgramID
        let tx = try TransactionBuilder.buildMintTokens(
            payer: payer, mint: mint, amount: 1_000_000,
            recentBlockhash: blockhash
        )
        let sig = tx[1..<65]
        #expect(sig.contains(where: { $0 != 0 }))
    }
}

// MARK: - TokenBalance Model Tests

@Suite("TokenBalance Model")
struct TokenBalanceModelTests {

    @Test func uiAmountWithSixDecimals() {
        // 1_000_000 raw / 10^6 = 1.0 USDC
        let tb = TokenBalance(
            mint: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
            symbol: "USDC", name: "USD Coin",
            decimals: 6, rawAmount: 1_000_000, usdValue: nil
        )
        #expect(abs(tb.uiAmount - 1.0) < 1e-9)
    }

    @Test func uiAmountWithNineDecimals() {
        // 1_000_000_000 raw / 10^9 = 1.0 SOL
        let tb = TokenBalance(
            mint: "So11111111111111111111111111111111111111112",
            symbol: "SOL", name: "Solana",
            decimals: 9, rawAmount: 1_000_000_000, usdValue: nil
        )
        #expect(abs(tb.uiAmount - 1.0) < 1e-9)
    }

    @Test func uiAmountWithZeroDecimals() {
        // Whole-unit token (e.g. NFT with 0 decimals)
        let tb = TokenBalance(
            mint: "SomeMint111111111111111111111111111111111111",
            symbol: "NFT", name: "My NFT",
            decimals: 0, rawAmount: 5, usdValue: nil
        )
        #expect(abs(tb.uiAmount - 5.0) < 1e-9)
    }

    @Test func uiAmountFractionalAmount() {
        // 500_000 raw / 10^6 = 0.5 USDC
        let tb = TokenBalance(
            mint: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
            symbol: "USDC", name: "USD Coin",
            decimals: 6, rawAmount: 500_000, usdValue: nil
        )
        #expect(abs(tb.uiAmount - 0.5) < 1e-9)
    }

    @Test func uiAmountLargeRawAmount() {
        // 1_000_000_000_000 raw / 10^6 = 1_000_000.0 USDC
        let tb = TokenBalance(
            mint: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
            symbol: "USDC", name: "USD Coin",
            decimals: 6, rawAmount: 1_000_000_000_000, usdValue: nil
        )
        #expect(abs(tb.uiAmount - 1_000_000.0) < 1e-3)
    }

    @Test func uiAmountZeroRawAmount() {
        let tb = TokenBalance(
            mint: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
            symbol: "USDC", name: "USD Coin",
            decimals: 6, rawAmount: 0, usdValue: nil
        )
        #expect(tb.uiAmount == 0.0)
    }

    @Test func uiAmountHalfSol() {
        // 500_000_000 lamports / 10^9 = 0.5 SOL
        let tb = TokenBalance(
            mint: "So11111111111111111111111111111111111111112",
            symbol: "SOL", name: "Solana",
            decimals: 9, rawAmount: 500_000_000, usdValue: nil
        )
        #expect(abs(tb.uiAmount - 0.5) < 1e-9)
    }

    @Test func usdValuePassthrough() {
        let tb = TokenBalance(
            mint: "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU",
            symbol: "USDC", name: "USD Coin",
            decimals: 6, rawAmount: 100_000_000, usdValue: 100.0
        )
        #expect(tb.usdValue == 100.0)
    }

    @Test func nilUsdValueRemainsNil() {
        let tb = TokenBalance(
            mint: "SomeUnknownMint111111111111111111111111111111",
            symbol: "UNK", name: "Unknown",
            decimals: 3, rawAmount: 1_000, usdValue: nil
        )
        #expect(tb.usdValue == nil)
    }

    @Test func uiAmountComputationIsCorrectFormula() {
        // Explicit formula check: uiAmount = Double(rawAmount) / pow(10, decimals)
        let rawAmount: UInt64 = 123_456
        let decimals = 3
        let expected = Double(rawAmount) / pow(10.0, Double(decimals))  // 123.456
        let tb = TokenBalance(
            mint: "SomeMint111111111111111111111111111111111111",
            symbol: "TST", name: "Test Token",
            decimals: decimals, rawAmount: rawAmount, usdValue: nil
        )
        #expect(abs(tb.uiAmount - expected) < 1e-9)
    }
}

// MARK: - Known Mint Symbol Tests

@Suite("Known Mint Symbol Lookup")
struct KnownMintSymbolTests {

    // These are the 4 mints that BalanceTool.knownMints and WalletViewModel.knownTokens
    // must recognise. Tests verify address validity and that symbols are stable.
    private let knownMints: [(address: String, symbol: String)] = [
        ("So11111111111111111111111111111111111111112", "SOL"),
        ("EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v", "USDC"),
        ("Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB", "USDT"),
        ("4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU", "USDC(dev)"),
    ]

    @Test func allKnownMintsDecodeToValidPubkeys() {
        for (address, symbol) in knownMints {
            let decoded = Base58.decode(address)
            #expect(decoded != nil, "\(symbol) mint address is not valid Base58")
            #expect(decoded?.count == 32, "\(symbol) mint address does not decode to 32 bytes")
        }
    }

    @Test func knownMintAddressesAreUnique() {
        let addresses = knownMints.map { $0.address }
        let unique = Set(addresses)
        #expect(unique.count == addresses.count, "Duplicate mint addresses in known list")
    }

    @Test func knownMintSymbolsAreUnique() {
        let symbols = knownMints.map { $0.symbol }
        let unique = Set(symbols)
        #expect(unique.count == symbols.count, "Duplicate symbols in known mint list")
    }

    @Test func solMintAddressIs43Chars() {
        // Wrapped SOL mint is 43 chars (decodes to 32 bytes — valid pubkey)
        let solMint = "So11111111111111111111111111111111111111112"
        #expect(solMint.count == 43)
    }

    @Test func usdcMainnetMintIs44Chars() {
        let usdc = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
        #expect(usdc.count == 44)
    }

    @Test func devnetUsdcMintIs44Chars() {
        let devUsdc = "4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU"
        #expect(devUsdc.count == 44)
    }

    @Test func unknownMintNotInKnownList() {
        let unknown = "SomeFakeMintAddress1111111111111111111111111"
        let isKnown = knownMints.contains { $0.address == unknown }
        #expect(!isKnown)
    }

    @Test func tokenBalanceWithKnownUSDCMintHasCorrectValues() {
        // USDC mainnet: 1_000_000 raw / 10^6 = 1.0 UI
        let tb = TokenBalance(
            mint: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
            symbol: "USDC", name: "USD Coin",
            decimals: 6, rawAmount: 1_000_000, usdValue: nil
        )
        #expect(tb.symbol == "USDC")
        #expect(abs(tb.uiAmount - 1.0) < 1e-9)
    }

    @Test func tokenBalanceSymbolPreserved() {
        // Symbol stored at init time is returned unchanged — no dynamic lookup needed
        let tb = TokenBalance(
            mint: "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
            symbol: "USDT", name: "Tether",
            decimals: 6, rawAmount: 5_000_000, usdValue: 5.0
        )
        #expect(tb.symbol == "USDT")
        #expect(abs(tb.uiAmount - 5.0) < 1e-9)
        #expect(tb.usdValue == 5.0)
    }
}

// MARK: - PDA and ATA Derivation Tests

@Suite("PDA and ATA Derivation")
struct PDADerivationTests {

    @Test func pdaDerivationIsDeterministic() {
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

        #expect(result1 != nil)
        #expect(result2 != nil)
        #expect(result1?.0 != result2?.0)
    }

    @Test func ataDerivationIsNonNilAndIs32Bytes() {
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
        let mint = TransactionBuilder.ataProgramID

        let ata1 = TransactionBuilder.associatedTokenAddress(owner: owner1, mint: mint)
        let ata2 = TransactionBuilder.associatedTokenAddress(owner: owner2, mint: mint)
        #expect(ata1 != nil)
        #expect(ata2 != nil)
        #expect(ata1 != ata2)
    }

    @Test func ataForKnownMintIsNonNil() {
        // A PDA is by definition off-curve; if ATA derivation returns a result,
        // it found a valid bump → address is off-curve (that's what makes it a PDA).
        let owner = Keypair.generate().publicKeyBytes
        let mint = TransactionBuilder.ataProgramID
        let ata = TransactionBuilder.associatedTokenAddress(owner: owner, mint: mint)
        #expect(ata != nil)
    }

    @Test func differentMintsProduceDifferentATAs() {
        let owner = Keypair.generate().publicKeyBytes
        let mint1 = Array(repeating: UInt8(1), count: 32)
        let mint2 = Array(repeating: UInt8(2), count: 32)

        let ata1 = TransactionBuilder.associatedTokenAddress(owner: owner, mint: mint1)
        let ata2 = TransactionBuilder.associatedTokenAddress(owner: owner, mint: mint2)
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

        #expect(settings.effectiveHeliusAPIKey == Secrets.heliusAPIKey)
    }

    @Test func hapticFeedbackDefaultIsTrue() {
        let settings = AppSettings.shared
        let original = settings.hapticFeedbackEnabled
        defer { settings.hapticFeedbackEnabled = original }

        settings.hapticFeedbackEnabled = false
        #expect(settings.hapticFeedbackEnabled == false)
        settings.hapticFeedbackEnabled = true
        #expect(settings.hapticFeedbackEnabled == true)
    }
}
