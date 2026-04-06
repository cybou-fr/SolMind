import Foundation

// MARK: - Solana Transaction Builder
// Builds and serializes Solana transactions for the subset needed by SolMind.
// Reference: https://docs.solana.com/developing/programming-model/transactions

struct TransactionBuilder {

    // System Program ID (all 1s in base58)
    static let systemProgramID: [UInt8] = Array(repeating: 0, count: 32)

    // Token Program ID
    static let tokenProgramID: [UInt8] = Base58.decode("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")!

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
