import Foundation
import CryptoKit

// MARK: - Solana Transaction Builder
// Builds and serializes Solana transactions for the subset needed by SolMind.
// Reference: https://docs.solana.com/developing/programming-model/transactions

struct TransactionBuilder {

    // System Program ID (all 1s in base58)
    static let systemProgramID: [UInt8] = Array(repeating: 0, count: 32)

    // Token Program ID
    static let tokenProgramID: [UInt8] = Base58.decode("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")!

    // Associated Token Account Program ID
    static let ataProgramID: [UInt8] = Base58.decode("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJe1bFo")!

    // Rent-exempt minimums (hardcoded for devnet; formula: 3480 lamports/byte/year × 2 years × (size + 128))
    static let mintRentExemptLamports: UInt64 = 1_461_600   // 82-byte mint account
    static let tokenAccountRentExemptLamports: UInt64 = 2_039_280  // 165-byte token account

    // MARK: - SOL Transfer

    /// Build a signed serialized transaction that transfers `lamports` from `sender` to `recipient`.
    static func buildSOLTransfer(
        from sender: Keypair,
        to recipientBase58: String,
        lamports: UInt64,
        recentBlockhash: String
    ) throws -> Data {
        guard let recipientBytes = Base58.decode(recipientBase58), recipientBytes.count == 32 else {
            throw TransactionError.invalidAddress
        }
        guard let blockhashBytes = Base58.decode(recentBlockhash), blockhashBytes.count == 32 else {
            throw TransactionError.invalidBlockhash
        }

        let senderBytes = sender.publicKeyBytes

        // Accounts: [sender(signer+writable), recipient(writable), SystemProgram(readonly)]
        let accounts: [[UInt8]] = [senderBytes, recipientBytes, systemProgramID]

        // System Transfer instruction data: [2,0,0,0] + lamports as little-endian u64
        var instructionData = Data([2, 0, 0, 0])
        withUnsafeBytes(of: lamports.littleEndian) { instructionData.append(contentsOf: $0) }

        // Build message
        let message = buildMessage(
            accounts: accounts,
            blockhash: blockhashBytes,
            instructions: [
                TransactionInstruction(
                    programIdIndex: 2,   // SystemProgram at index 2
                    accountIndices: [0, 1],
                    data: instructionData
                )
            ],
            numRequiredSignatures: 1,
            numReadonlySignedAccounts: 0,
            numReadonlyUnsignedAccounts: 1   // SystemProgram
        )

        // Sign the message
        let signature = try sender.sign(message)

        // Serialize: compact-u16 sig count + sig bytes + message bytes
        var tx = Data()
        tx.append(contentsOf: encodeCompactU16(1))
        tx.append(signature)
        tx.append(message)
        return tx
    }

    // MARK: - PDA Derivation

    /// Solana `findProgramAddress` — iterates nonce from 255 down to 0. Returns nil only if none of
    /// the 256 candidates are off-curve (extremely unlikely in practice).
    static func findProgramAddress(seeds: [[UInt8]], programId: [UInt8]) -> ([UInt8], UInt8)? {
        for nonceInt in stride(from: 255, through: 0, by: -1) {
            let nonce = UInt8(nonceInt)
            var hashData = Data()
            for seed in seeds { hashData.append(contentsOf: seed) }
            hashData.append(nonce)
            hashData.append(contentsOf: programId)
            hashData.append(contentsOf: Array("ProgramDerivedAddress".utf8))
            let bytes = [UInt8](SHA256.hash(data: hashData))
            // Valid PDA if the hash is NOT a valid ed25519 point
            if (try? Curve25519.Signing.PublicKey(rawRepresentation: Data(bytes))) == nil {
                return (bytes, nonce)
            }
        }
        return nil
    }

    /// Derives the Associated Token Account address for a given owner and mint.
    static func associatedTokenAddress(owner: [UInt8], mint: [UInt8]) -> [UInt8]? {
        guard let (pda, _) = findProgramAddress(
            seeds: [owner, tokenProgramID, mint],
            programId: ataProgramID
        ) else { return nil }
        return pda
    }

    // MARK: - Create SPL Token Mint (2-signer transaction)

    /// Builds a transaction that creates a new SPL token mint.
    /// Requires two signers: `payer` (funding account) and `mintKeypair` (new mint address).
    /// Accounts: [payer(signer+writable), mint(signer+writable), SystemProgram(readonly), TokenProgram(readonly)]
    static func buildCreateMint(
        payer: Keypair,
        mintKeypair: Keypair,
        decimals: UInt8,
        recentBlockhash: String
    ) throws -> Data {
        guard let blockhashBytes = Base58.decode(recentBlockhash), blockhashBytes.count == 32 else {
            throw TransactionError.invalidBlockhash
        }

        let payerBytes = payer.publicKeyBytes
        let mintBytes = mintKeypair.publicKeyBytes

        // Account ordering: signer+writable, signer+writable, unsigned+readonly, unsigned+readonly
        let accounts: [[UInt8]] = [payerBytes, mintBytes, systemProgramID, tokenProgramID]

        // SystemProgram.createAccount — allocate 82 bytes owned by Token Program
        // Data: [0,0,0,0] (instruction index 0 as little-endian u32) + lamports (u64 LE) + space (u64 LE) + programId (32 bytes)
        var createAccountData = Data([0, 0, 0, 0])
        withUnsafeBytes(of: mintRentExemptLamports.littleEndian) { createAccountData.append(contentsOf: $0) }
        let mintSpace: UInt64 = 82
        withUnsafeBytes(of: mintSpace.littleEndian) { createAccountData.append(contentsOf: $0) }
        createAccountData.append(contentsOf: tokenProgramID)

        // Token Program InitializeMint2 (discriminator 20) — no rent sysvar required
        // Data: [20, decimals, mintAuthority (32), COption::Some (1), freezeAuthority (32)]
        var initMintData = Data([20, decimals])
        initMintData.append(contentsOf: payerBytes)  // mint authority = payer
        initMintData.append(1)                        // Some(freezeAuthority)
        initMintData.append(contentsOf: payerBytes)  // freeze authority = payer

        let message = buildMessage(
            accounts: accounts,
            blockhash: blockhashBytes,
            instructions: [
                TransactionInstruction(
                    programIdIndex: 2,         // SystemProgram
                    accountIndices: [0, 1],    // payer, new_mint
                    data: createAccountData
                ),
                TransactionInstruction(
                    programIdIndex: 3,         // TokenProgram
                    accountIndices: [1],       // mint
                    data: initMintData
                )
            ],
            numRequiredSignatures: 2,
            numReadonlySignedAccounts: 0,
            numReadonlyUnsignedAccounts: 2     // SystemProgram, TokenProgram
        )

        let payerSig = try payer.sign(message)
        let mintSig = try mintKeypair.sign(message)

        var tx = Data()
        tx.append(contentsOf: encodeCompactU16(2))
        tx.append(payerSig)
        tx.append(mintSig)
        tx.append(message)
        return tx
    }

    // MARK: - Mint SPL Tokens (create ATA + mintTo)

    /// Builds a transaction that idempotently creates the payer's ATA for `mint` and mints `amount` tokens.
    /// Accounts: [payer(signer+writable), ATA(writable), mint(writable), SystemProgram, TokenProgram, ATAProgram]
    static func buildMintTokens(
        payer: Keypair,
        mint: [UInt8],
        amount: UInt64,
        recentBlockhash: String
    ) throws -> Data {
        guard let blockhashBytes = Base58.decode(recentBlockhash), blockhashBytes.count == 32 else {
            throw TransactionError.invalidBlockhash
        }

        let payerBytes = payer.publicKeyBytes
        guard let ataBytes = associatedTokenAddress(owner: payerBytes, mint: mint) else {
            throw TransactionError.buildFailed("Could not derive Associated Token Account address")
        }

        // Account ordering: signer+writable (payer), unsigned+writable (ata, mint), unsigned+readonly (programs)
        let accounts: [[UInt8]] = [
            payerBytes,      // [0] signer+writable
            ataBytes,        // [1] unsigned+writable (ATA being created)
            mint,            // [2] unsigned+writable (supply updated by mintTo)
            systemProgramID, // [3] unsigned+readonly
            tokenProgramID,  // [4] unsigned+readonly
            ataProgramID     // [5] unsigned+readonly
        ]

        // ATA Program idempotent create (discriminator 1 = CreateIdempotent)
        // Accounts in instruction: payer[0], ata[1], owner(=payer)[0], mint[2], system[3], token[4]
        let createATAData = Data([1])

        // Token Program mintTo (discriminator 7)
        // Data: [7] + amount (u64 LE)
        var mintToData = Data([7])
        withUnsafeBytes(of: amount.littleEndian) { mintToData.append(contentsOf: $0) }

        let message = buildMessage(
            accounts: accounts,
            blockhash: blockhashBytes,
            instructions: [
                TransactionInstruction(
                    programIdIndex: 5,                       // ATAProgram
                    accountIndices: [0, 1, 0, 2, 3, 4],    // payer, ata, owner(=payer), mint, system, token
                    data: createATAData
                ),
                TransactionInstruction(
                    programIdIndex: 4,                       // TokenProgram
                    accountIndices: [2, 1, 0],              // mint, ata, authority(=payer)
                    data: mintToData
                )
            ],
            numRequiredSignatures: 1,
            numReadonlySignedAccounts: 0,
            numReadonlyUnsignedAccounts: 3    // SystemProgram, TokenProgram, ATAProgram
        )

        let sig = try payer.sign(message)

        var tx = Data()
        tx.append(contentsOf: encodeCompactU16(1))
        tx.append(sig)
        tx.append(message)
        return tx
    }

    // MARK: - Message Serialization

    private static func buildMessage(
        accounts: [[UInt8]],
        blockhash: [UInt8],
        instructions: [TransactionInstruction],
        numRequiredSignatures: UInt8,
        numReadonlySignedAccounts: UInt8,
        numReadonlyUnsignedAccounts: UInt8
    ) -> Data {
        var message = Data()

        // Header (3 bytes)
        message.append(numRequiredSignatures)
        message.append(numReadonlySignedAccounts)
        message.append(numReadonlyUnsignedAccounts)

        // Account addresses
        message.append(contentsOf: encodeCompactU16(UInt16(accounts.count)))
        for account in accounts {
            message.append(contentsOf: account)
        }

        // Recent blockhash
        message.append(contentsOf: blockhash)

        // Instructions
        message.append(contentsOf: encodeCompactU16(UInt16(instructions.count)))
        for instruction in instructions {
            message.append(instruction.programIdIndex)
            message.append(contentsOf: encodeCompactU16(UInt16(instruction.accountIndices.count)))
            message.append(contentsOf: instruction.accountIndices)
            message.append(contentsOf: encodeCompactU16(UInt16(instruction.data.count)))
            message.append(instruction.data)
        }

        return message
    }

    // MARK: - Compact-U16 Encoding (Solana wire format)

    static func encodeCompactU16(_ value: UInt16) -> [UInt8] {
        var v = value
        var result: [UInt8] = []
        repeat {
            var byte = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byte |= 0x80 }
            result.append(byte)
        } while v != 0
        return result
    }
}

// MARK: - Supporting Types

struct TransactionInstruction {
    let programIdIndex: UInt8
    let accountIndices: [UInt8]
    let data: Data
}

enum TransactionError: LocalizedError, Equatable {
    case invalidAddress
    case invalidBlockhash
    case insufficientFunds
    case buildFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "Invalid Solana address."
        case .invalidBlockhash: return "Invalid blockhash."
        case .insufficientFunds: return "Insufficient SOL balance."
        case .buildFailed(let msg): return "Transaction build failed: \(msg)"
        }
    }
}
