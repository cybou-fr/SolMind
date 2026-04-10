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
    static let ataProgramID: [UInt8] = Base58.decode("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJe1bQ")!

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
            // Valid PDA if the hash is NOT a valid Ed25519 curve point.
            // CryptoKit's PublicKey init does NOT validate on-curve, so we use a
            // proper GF(2^255-19) field check via isOnEd25519Curve().
            if !isOnEd25519Curve(bytes) {
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
        // Data: [20, decimals, mintAuthority (32), COption::Some (4 bytes u32 LE), freezeAuthority (32)]
        // COption<Pubkey> is Borsh-encoded: None = [0,0,0,0]  Some = [1,0,0,0] + 32 bytes
        var initMintData = Data([20, decimals])
        initMintData.append(contentsOf: payerBytes)          // mint authority = payer
        initMintData.append(contentsOf: [1, 0, 0, 0])       // COption::Some (u32 LE = 4 bytes)
        initMintData.append(contentsOf: payerBytes)          // freeze authority = payer

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

    // MARK: - SPL Token Transfer

    /// Builds a signed transaction that transfers SPL tokens from the sender's ATA to the recipient's ATA.
    /// Idempotently creates the recipient's ATA if it does not yet exist (sender pays ~0.002 SOL rent).
    ///
    /// Accounts layout:
    ///   [0] payer/sender  — signer+writable
    ///   [1] sourceATA     — writable  (sender's ATA for the mint)
    ///   [2] recipientATA  — writable  (recipient's ATA; created if absent)
    ///   [3] mint          — readonly
    ///   [4] recipient     — readonly  (ATA owner, needed for idempotent create)
    ///   [5] SystemProgram — readonly
    ///   [6] TokenProgram  — readonly
    ///   [7] ATAProgram    — readonly
    static func buildSPLTransfer(
        from sender: Keypair,
        to recipientBase58: String,
        mintBase58: String,
        amount: UInt64,         // raw token units (already multiplied by 10^decimals)
        recentBlockhash: String
    ) throws -> Data {
        guard let recipientBytes = Base58.decode(recipientBase58), recipientBytes.count == 32 else {
            throw TransactionError.invalidAddress
        }
        guard let mintBytes = Base58.decode(mintBase58), mintBytes.count == 32 else {
            throw TransactionError.buildFailed("Invalid mint address")
        }
        guard let blockhashBytes = Base58.decode(recentBlockhash), blockhashBytes.count == 32 else {
            throw TransactionError.invalidBlockhash
        }

        let senderBytes = sender.publicKeyBytes

        guard let sourceATA = associatedTokenAddress(owner: senderBytes, mint: mintBytes) else {
            throw TransactionError.buildFailed("Could not derive sender ATA")
        }
        guard let recipientATA = associatedTokenAddress(owner: recipientBytes, mint: mintBytes) else {
            throw TransactionError.buildFailed("Could not derive recipient ATA")
        }

        let accounts: [[UInt8]] = [
            senderBytes,      // [0] signer+writable (payer for rent if needed)
            sourceATA,        // [1] writable (token source)
            recipientATA,     // [2] writable (token destination, may be created)
            mintBytes,        // [3] readonly
            recipientBytes,   // [4] readonly (ATA owner for idempotent create)
            systemProgramID,  // [5] readonly
            tokenProgramID,   // [6] readonly
            ataProgramID      // [7] readonly
        ]

        // Idempotently create the recipient ATA (no-op if already exists)
        // ATA Program CreateIdempotent: discriminator 1
        let createATAData = Data([1])

        // Token Program Transfer: discriminator 3 + amount (u64 LE)
        var transferData = Data([3])
        withUnsafeBytes(of: amount.littleEndian) { transferData.append(contentsOf: $0) }

        let message = buildMessage(
            accounts: accounts,
            blockhash: blockhashBytes,
            instructions: [
                // Create recipient ATA if needed
                TransactionInstruction(
                    programIdIndex: 7,                         // ATAProgram
                    accountIndices: [0, 2, 4, 3, 5, 6],      // payer, recipientATA, recipient, mint, system, token
                    data: createATAData
                ),
                // Transfer tokens from source to destination
                TransactionInstruction(
                    programIdIndex: 6,                         // TokenProgram
                    accountIndices: [1, 2, 0],                // sourceATA, recipientATA, authority(=sender)
                    data: transferData
                )
            ],
            numRequiredSignatures: 1,
            numReadonlySignedAccounts: 0,
            numReadonlyUnsignedAccounts: 5     // mint[3], recipient[4], SystemProgram[5], TokenProgram[6], ATAProgram[7]
        )

        let sig = try sender.sign(message)

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

// MARK: - Ed25519 On-Curve Validation

/// Private GF(2²⁵⁵−19) field arithmetic used exclusively by `isOnEd25519Curve`.
/// CryptoKit's `Curve25519.Signing.PublicKey(rawRepresentation:)` accepts all 32-byte
/// values without performing on-curve validation, so we implement the check ourselves.
private extension TransactionBuilder {

    // Field element: 4 × UInt64, little-endian (limbs[0] = least significant)
    typealias FE = [UInt64]

    // p = 2^255 − 19
    static let feP: FE = [0xFFFFFFFFFFFFFFED, 0xFFFFFFFFFFFFFFFF,
                           0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF]
    // d = −121665/121666 mod p (Edwards curve constant)
    static let feD: FE = [0x75EB4DCA135978A3, 0x00700A4D4141D8AB,
                           0x8CC740797779E898, 0x52036CEE2B6FFE73]
    // (p−1)/2 — exponent for Euler / Legendre criterion
    static let feHalfPm1: FE = [0xFFFFFFFFFFFFFFF6, 0xFFFFFFFFFFFFFFFF,
                                 0xFFFFFFFFFFFFFFFF, 0x3FFFFFFFFFFFFFFF]
    // p−2 — exponent for modular inverse (Fermat's little theorem)
    static let fePm2: FE = [0xFFFFFFFFFFFFFFEB, 0xFFFFFFFFFFFFFFFF,
                             0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF]

    /// Returns true if `bytes` represents a valid (on-curve) Ed25519 point.
    /// Solana PDAs must be off-curve, so `findProgramAddress` returns bytes for
    /// which this function returns **false**.
    static func isOnEd25519Curve(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 32 else { return false }
        var yb = bytes
        yb[31] &= 0x7F                        // clear sign bit to get y coordinate
        let y  = feLoad(yb)
        let y2 = feMul(y, y)
        let u  = feSub(y2, [1, 0, 0, 0])      // u = y² − 1
        let v  = feAdd(feMul(feD, y2), [1, 0, 0, 0])  // v = d·y² + 1
        if feCmp(v, [0, 0, 0, 0]) == 0 { return feCmp(u, [0, 0, 0, 0]) == 0 }
        let x2     = feMul(u, fePow(v, fePm2))     // x² = u / v  (Fermat inverse)
        let euler  = fePow(x2, feHalfPm1)           // x²^((p−1)/2)
        return feCmp(euler, [1, 0, 0, 0]) == 0 || feCmp(euler, [0, 0, 0, 0]) == 0
    }

    // MARK: Field helpers

    static func feLoad(_ bytes: [UInt8]) -> FE {
        var fe = FE(repeating: 0, count: 4)
        for i in 0..<4 {
            fe[i] = (0..<8).reduce(0) { $0 | UInt64(bytes[i*8 + $1]) << ($1 * 8) }
        }
        return fe
    }

    static func feCmp(_ a: FE, _ b: FE) -> Int {
        for i in stride(from: 3, through: 0, by: -1) {
            if a[i] < b[i] { return -1 }
            if a[i] > b[i] { return  1 }
        }
        return 0
    }

    /// Subtraction without reduction — caller must guarantee a ≥ b.
    static func feSub0(_ a: FE, _ b: FE) -> FE {
        var r = FE(repeating: 0, count: 4); var borrow: UInt64 = 0
        for i in 0..<4 {
            let (s1, o1) = a[i].subtractingReportingOverflow(b[i])
            let (s2, o2) = s1.subtractingReportingOverflow(borrow)
            r[i] = s2; borrow = (o1 || o2) ? 1 : 0
        }
        return r
    }

    static func feAdd(_ a: FE, _ b: FE) -> FE {
        var r = FE(repeating: 0, count: 4); var carry: UInt64 = 0
        for i in 0..<4 {
            let (s1, o1) = a[i].addingReportingOverflow(b[i])
            let (s2, o2) = s1.addingReportingOverflow(carry)
            r[i] = s2; carry = (o1 || o2) ? 1 : 0
        }
        if carry != 0 || feCmp(r, feP) >= 0 { return feSub0(r, feP) }
        return r
    }

    static func feSub(_ a: FE, _ b: FE) -> FE {
        feCmp(a, b) >= 0 ? feSub0(a, b) : feAdd(a, feSub0(feP, b))
    }

    /// Schoolbook 256×256-bit multiply, reduced mod p using 2²⁵⁶ ≡ 38 (mod p).
    static func feMul(_ a: FE, _ b: FE) -> FE {
        var r = [UInt64](repeating: 0, count: 8)
        for i in 0..<4 {
            for j in 0..<4 {
                let (hi, lo) = a[i].multipliedFullWidth(by: b[j])
                var c = lo; var k = i + j
                while c != 0 && k < 8 {
                    let (s, o) = r[k].addingReportingOverflow(c); r[k] = s; c = o ? 1 : 0; k += 1
                }
                c = hi; k = i + j + 1
                while c != 0 && k < 8 {
                    let (s, o) = r[k].addingReportingOverflow(c); r[k] = s; c = o ? 1 : 0; k += 1
                }
            }
        }
        // Reduce: split into high (r[4..7]) and low (r[0..3])
        // n ≡ high × 38 + low  (mod p)
        var scaled = [UInt64](repeating: 0, count: 5); var carry: UInt64 = 0
        for i in 0..<4 {
            let (hi, lo) = r[i + 4].multipliedFullWidth(by: 38)
            let (s, c) = lo.addingReportingOverflow(carry)
            scaled[i] = s; carry = hi &+ (c ? 1 : 0)
        }
        scaled[4] = carry
        var partial = [UInt64](repeating: 0, count: 5); carry = 0
        for i in 0..<4 {
            let (s1, c1) = scaled[i].addingReportingOverflow(r[i])
            let (s2, c2) = s1.addingReportingOverflow(carry)
            partial[i] = s2; carry = (c1 || c2) ? 1 : 0
        }
        partial[4] = scaled[4] &+ carry
        // Final step: extract q = partial >> 255, rem = partial & (2²⁵⁵ − 1)
        let q   = (partial[3] >> 63) | (partial[4] << 1)
        let rem: FE = [partial[0], partial[1], partial[2], partial[3] & 0x7FFFFFFFFFFFFFFF]
        return feAdd(rem, [q * 19, 0, 0, 0])
    }

    /// Square-and-multiply exponentiation: base^exp mod p.
    static func fePow(_ base: FE, _ exp: FE) -> FE {
        var result: FE = [1, 0, 0, 0]; var b = base; var e = exp
        for _ in 0..<256 {
            if e[0] & 1 == 1 { result = feMul(result, b) }
            b = feMul(b, b)
            e[0] = (e[0] >> 1) | (e[1] << 63)
            e[1] = (e[1] >> 1) | (e[2] << 63)
            e[2] = (e[2] >> 1) | (e[3] << 63)
            e[3] >>= 1
        }
        return result
    }
}
