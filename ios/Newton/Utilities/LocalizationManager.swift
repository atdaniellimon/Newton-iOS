//
//  LocalizationManager.swift
//  Newton
//
//  Centralized Localization Engine for Newton iOS.
//  Defaults to English, automatically switches to Spanish when system locale is Spanish.
//  Also allows explicit in-app language override.
//

import Foundation
import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case spanish = "es"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return LocalizationManager.shared.isSpanish ? "Sistema (Predeterminado)" : "System (Default)"
        case .english:
            return "English"
        case .spanish:
            return "Español"
        }
    }
}

public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    private let storageKey = "newton_app_language_preference"

    @Published public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: storageKey)
            updateEffectiveLanguage()
        }
    }

    @Published public private(set) var isSpanish: Bool = false

    private init() {
        let savedRaw = UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.system.rawValue
        let initialLang = AppLanguage(rawValue: savedRaw) ?? .system
        self.language = initialLang
        self.isSpanish = Self.computeIsSpanish(for: initialLang)

        NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.language == .system else { return }
            self.updateEffectiveLanguage()
        }
    }

    public func updateEffectiveLanguage() {
        let newIsSpanish = Self.computeIsSpanish(for: language)
        if self.isSpanish != newIsSpanish {
            self.isSpanish = newIsSpanish
            self.objectWillChange.send()
        }
    }

    private static func computeIsSpanish(for lang: AppLanguage) -> Bool {
        switch lang {
        case .english:
            return false
        case .spanish:
            return true
        case .system:
            if let firstPref = Locale.preferredLanguages.first?.lowercased() {
                if firstPref.hasPrefix("es") {
                    return true
                }
            }
            let code: String?
            if #available(iOS 16.0, *) {
                code = Locale.current.language.languageCode?.identifier.lowercased()
            } else {
                code = Locale.current.languageCode?.lowercased()
            }
            return code == "es"
        }
    }
}

public struct L10n {
    /// Translates between English (primary/default) and Spanish (if system or user is set to Spanish).
    public static func tr(_ en: String, es: String) -> String {
        LocalizationManager.shared.isSpanish ? es : en
    }
}
