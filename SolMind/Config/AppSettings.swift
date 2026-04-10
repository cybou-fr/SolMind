import Foundation
import Observation

/// Runtime-editable app settings backed by UserDefaults.
/// Keys stored here override the compiled-in Secrets.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    // MARK: - API Keys

    var heliusAPIKey: String = "" {
        didSet { UserDefaults.standard.set(heliusAPIKey, forKey: Key.helius) }
    }

    var moonpayAPIKey: String = "" {
        didSet { UserDefaults.standard.set(moonpayAPIKey, forKey: Key.moonpay) }
    }

    // MARK: - Preferences

    var hapticFeedbackEnabled: Bool = true {
        didSet { UserDefaults.standard.set(hapticFeedbackEnabled, forKey: Key.haptics) }
    }

    // MARK: - Effective values (fall back to Secrets if field is blank)

    var effectiveHeliusAPIKey: String {
        heliusAPIKey.isEmpty ? Secrets.heliusAPIKey : heliusAPIKey
    }

    var effectiveMoonpayAPIKey: String {
        moonpayAPIKey.isEmpty ? Secrets.moonpayAPIKey : moonpayAPIKey
    }

    // MARK: - Init / Load

    private init() {
        let d = UserDefaults.standard
        heliusAPIKey          = d.string(forKey: Key.helius)  ?? ""
        moonpayAPIKey         = d.string(forKey: Key.moonpay) ?? ""
        hapticFeedbackEnabled = d.object(forKey: Key.haptics) as? Bool ?? true
    }

    func resetAPIKeys() {
        heliusAPIKey  = ""
        moonpayAPIKey = ""
    }

    // MARK: - User-created token registry

    /// Persist a token created via the createToken AI tool so Portfolio can show its name/symbol.
    func registerToken(mint: String, symbol: String, name: String) {
        var tokens = userCreatedTokenDict
        tokens[mint] = ["symbol": symbol, "name": name]
        if let data = try? JSONSerialization.data(withJSONObject: tokens) {
            UserDefaults.standard.set(data, forKey: Key.userTokens)
        }
    }

    /// Returns (symbol, name) for a user-created token, or nil if not found.
    func tokenMetadata(for mint: String) -> (symbol: String, name: String)? {
        guard let info = userCreatedTokenDict[mint],
              let sym  = info["symbol"],
              let nm   = info["name"] else { return nil }
        return (symbol: sym, name: nm)
    }

    private var userCreatedTokenDict: [String: [String: String]] {
        guard let data = UserDefaults.standard.data(forKey: Key.userTokens),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        else { return [:] }
        return dict
    }

    // MARK: - Keys

    private enum Key {
        static let helius     = "solmind.heliusAPIKey"
        static let moonpay    = "solmind.moonpayAPIKey"
        static let haptics    = "solmind.hapticFeedbackEnabled"
        static let userTokens = "solmind.userCreatedTokens"
    }
}
