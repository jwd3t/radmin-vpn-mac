// SPDX-License-Identifier: GPL-3.0-only
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, es, ru

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L("language.system")
        case .en: return "English"
        case .es: return "Español"
        case .ru: return "Русский"
        }
    }
}

private func selectedLanguageCode() -> String? {
    guard let raw = UserDefaults.standard.string(forKey: "appLanguage"),
          let language = AppLanguage(rawValue: raw),
          language != .system else {
        return nil
    }
    return language.rawValue
}

private func localizationBundle() -> Bundle {
    if let code = selectedLanguageCode(),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle
    }
    return Bundle.main
}

func L(_ key: String) -> String {
    localizationBundle().localizedString(forKey: key, value: nil, table: nil)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = L(key)
    let locale = selectedLanguageCode().map { Locale(identifier: $0) } ?? Locale.current
    return String(format: format, locale: locale, arguments: args)
}
