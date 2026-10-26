import Foundation

// 所有应用文案共用标准 Bundle 本地化，缺失翻译时使用资源键兜底。
func L(_ key: String, _ arguments: CVarArg...) -> String {
    let value = NSLocalizedString(key, bundle: .main, value: key, comment: "")
    return arguments.isEmpty ? value : String(format: value, locale: Locale.current, arguments: arguments)
}

enum AppLanguage {
    static let supported: [(code: String, name: String)] = [
        ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("en", "English"),
        ("ja", "日本語"), ("ko", "한국어"), ("fr", "Français"),
        ("de", "Deutsch"), ("es", "Español"), ("pt", "Português"),
        ("it", "Italiano"), ("ru", "Русский"), ("ar", "العربية")
    ]

    static var override: String? {
        guard let identifier = Bundle.main.bundleIdentifier,
              let languages = UserDefaults.standard.persistentDomain(forName: identifier)?["AppleLanguages"] as? [String]
        else { return nil }
        return Bundle.preferredLocalizations(from: supported.map(\.code), forPreferences: languages).first
    }
}
