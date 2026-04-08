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

    // MARK: - Keys

    private enum Key {
        static let helius  = "solmind.heliusAPIKey"
        static let moonpay = "solmind.moonpayAPIKey"
        static let haptics = "solmind.hapticFeedbackEnabled"
    }
}
