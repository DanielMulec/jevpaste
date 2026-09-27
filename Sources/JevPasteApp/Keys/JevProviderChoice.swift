import Foundation
import SmartPasteCore

/// The Jev Provider chosen in Settings, kept in the app's defaults under `jevProvider`. Nothing chosen or an unknown
/// value reads as the default, the Vercel AI Gateway.
@MainActor
struct JevProviderChoice {
    private static let key = "jevProvider"

    let defaults: UserDefaults

    var provider: JevProvider {
        defaults.string(forKey: Self.key).flatMap(JevProvider.init(rawValue:)) ?? .standard
    }

    func choose(_ provider: JevProvider) {
        defaults.set(provider.rawValue, forKey: Self.key)
    }
}
