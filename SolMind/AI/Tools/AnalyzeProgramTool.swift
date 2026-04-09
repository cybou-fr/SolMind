import FoundationModels
import Foundation

// MARK: - Analyze Program / Account Tool

struct AnalyzeProgramTool: Tool {
    let name = "analyzeProgram"
    let description = "Look up any Solana program or account by base58 address or name (e.g. Jupiter, Raydium, Metaplex)."

    private let solanaClient: SolanaClient

    init(solanaClient: SolanaClient) {
        self.solanaClient = solanaClient
    }

    @Generable
    struct Arguments {
        @Guide(description: "Base58 address or program name")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let input = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            return "Please provide a Solana address or program name to look up."
        }

        // 1. If it looks like a base58 address, try direct lookup first
        let looksLikeAddress = input.count >= 32 && input.count <= 44
        if looksLikeAddress {
            if let known = KnownPrograms.info(for: input) {
                return formatProgramInfo(known)
            }
            // Unknown address — fetch from chain
            return await fetchAndDescribeAccount(address: input)
        }

        // 2. Name / keyword search against known programs
        let results = KnownPrograms.search(name: input)
        if !results.isEmpty {
            let sorted = results.sorted { $0.name < $1.name }
            return formatSearchResults(sorted, query: input)
        }

        // 3. Nothing found
        return """
            No known Solana program matches "\(input)". \
            Try a specific program address, or names like: \
            Jupiter, Raydium, Orca, Marinade, Metaplex, SPL Token, Squads, Wormhole, OpenBook, Solend.
            """
    }

    // MARK: - On-chain Fetch

    private func fetchAndDescribeAccount(address: String) async -> String {
        do {
            guard let info = try await solanaClient.getAccountInfo(address: address) else {
                return """
                    Account `\(address)` was not found on Solana devnet. \
                    It may not exist yet or may not have been funded.
                    """
            }

            var lines: [String] = []
            lines.append("**Account: `\(address)`**")
            lines.append("")

            let sol = Double(info.lamports) / 1_000_000_000
            lines.append("- **Balance:** \(String(format: "%.9f", sol)) SOL (\(info.lamports) lamports)")
            lines.append("- **Type:** \(info.executable ? "Executable program" : "Data / wallet account")")

            // Identify owner
            if let ownerInfo = KnownPrograms.info(for: info.owner) {
                lines.append("- **Owned by:** \(ownerInfo.name) (`\(info.owner)`)")
                lines.append("  *\(ownerInfo.description)*")
            } else {
                lines.append("- **Owned by:** `\(info.owner)`")
            }

            lines.append("")
            if info.executable {
                lines.append("This is an **on-chain program** not in the known programs registry. It could be a custom protocol, a project-specific smart contract, or a devnet deployment.")
            } else if info.owner == "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" {
                lines.append("This is an **SPL Token account** — it holds a token balance for one token type.")
            } else if info.owner == "11111111111111111111111111111111" {
                lines.append("This is a **wallet account** (system-owned). It holds SOL and can sign transactions.")
            } else {
                lines.append("This is a **data account** used by the owning program above to store state.")
            }

            return lines.joined(separator: "\n")
        } catch {
            return "Could not fetch account info for `\(address)`: \(error.localizedDescription)"
        }
    }

    // MARK: - Formatting

    private func formatProgramInfo(_ p: ProgramInfo) -> String {
        var lines: [String] = []
        lines.append("**\(p.name)** [\(p.category)]")
        lines.append("Address: `\(p.address)`")
        lines.append("")
        lines.append(p.description)
        if let website = p.website {
            lines.append("")
            lines.append("Website: \(website)")
        }
        return lines.joined(separator: "\n")
    }

    private func formatSearchResults(_ programs: [ProgramInfo], query: String) -> String {
        if programs.count == 1 {
            return formatProgramInfo(programs[0])
        }
        let header = "Found \(programs.count) programs matching \"\(query)\":"
        let body = programs.map { p in
            "**\(p.name)** [\(p.category)]\n`\(p.address)`\n\(p.description)"
        }.joined(separator: "\n\n")
        return "\(header)\n\n\(body)"
    }
}
