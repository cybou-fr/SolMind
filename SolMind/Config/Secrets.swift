// Secrets.swift — NOT committed to git (see .gitignore)
// Copy from Secrets.example.swift and fill in your real keys.
// Leave these as "" to use the free public devnet RPC.
// NFT features (getAssets, mintCompressedNft) require a real Helius API key — get one free at helius.dev
enum Secrets {
    static let heliusAPIKey = ""   // replace with your Helius devnet API key for NFT + higher RPC rate limits
    static let moonpayAPIKey = ""  // replace with your MoonPay sandbox key to enable on-ramp
}
