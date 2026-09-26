import SmartPasteCore

/// Where the Settings window opens: a tab, or the Jev Provider tab with one provider's key field focused (from the
/// "No key for <provider> — open Settings" refusal).
enum SettingsSection: Equatable {
    case general
    case jevProvider
    case fullHistory
    case key(JevProvider)
}
