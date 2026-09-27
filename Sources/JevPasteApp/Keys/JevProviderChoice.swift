import Foundation
import JevGateway
import SmartPasteCore

/// The Jev Provider chosen in Settings, kept in the app's defaults under `jevProvider`. Nothing chosen, an unknown
/// value or a provider that is not built yet reads as the default, the Vercel AI Gateway.
@MainActor
struct JevProviderChoice {
    private static let key = "jevProvider"

    let defaults: UserDefaults

    var provider: JevProvider {
        let stored = defaults.string(forKey: Self.key).flatMap(JevProvider.init(rawValue:))
        return stored.flatMap { JevGatewayAccess.builtProviders.contains($0) ? $0 : nil } ?? .standard
    }

    func choose(_ provider: JevProvider) {
        defaults.set(provider.rawValue, forKey: Self.key)
    }
}
