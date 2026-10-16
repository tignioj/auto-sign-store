import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", simplifiedChinese = "zh-Hans"

    static let preferenceKey = "appLanguage"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: L10n.tr("language.system")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for language in preferredLanguages {
            switch language.lowercased().split(separator: "-").first {
            case "zh": return .simplifiedChinese
            case "en": return .english
            default: continue
            }
        }
        return .english
    }

    var locale: Locale { Locale(identifier: resolved().rawValue) }
}

/// Shared by the app target and Swift Package core tests. Language changes never alter API data.
enum L10n {
    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLanguage.preferenceKey) ?? "") ?? .system
    }
    static var locale: Locale { language.locale }

    static let resourceBundle: Bundle = {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }()

    static func bundle(for locale: Locale) -> Bundle {
        let language = AppLanguage.system.resolved(preferredLanguages: [locale.identifier.replacingOccurrences(of: "_", with: "-")])
        // SwiftPM lowercases localization directories; Xcode preserves their original case.
        let localization = resourceBundle.localizations.first {
            $0.caseInsensitiveCompare(language.rawValue) == .orderedSame
        } ?? language.rawValue
        guard let path = resourceBundle.path(forResource: localization, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return resourceBundle }
        return bundle
    }

    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        string(key, locale: locale, arguments: arguments)
    }

    static func string(_ key: String, locale: Locale, arguments: [CVarArg] = []) -> String {
        let format = bundle(for: locale).localizedString(forKey: key, value: nil, table: "Localizable")
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    static func date(_ date: Date, includeTime: Bool = true, locale: Locale = L10n.locale) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: includeTime ? .shortened : .omitted).locale(locale))
    }

    static func fileSize(_ bytes: Int64, locale: Locale = L10n.locale) -> String {
        bytes.formatted(.byteCount(style: .file).locale(locale))
    }
}
