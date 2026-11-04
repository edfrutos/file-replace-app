import Foundation

/// Idioma de la interfaz. Los textos van en el código como pares
/// `tr("español", "English")` porque el ejecutable de SwiftPM no empaqueta
/// recursos de bundle (ver CHANGELOG 1.2.0, `Bundle.module`).
public enum AppLanguage: String, Sendable {
    case spanish = "es"
    case english = "en"

    /// El primero de los idiomas preferidos del usuario —incluido el idioma por
    /// app de Ajustes del Sistema— que sea español o inglés; si no hay ninguno,
    /// inglés.
    public static let current = resolve(Locale.preferredLanguages)

    public static func resolve(_ preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let code = identifier.lowercased()
            if code.hasPrefix("es") { return .spanish }
            if code.hasPrefix("en") { return .english }
        }
        return .english
    }
}

/// Devuelve el texto en el idioma de la interfaz.
public func tr(_ spanish: String, _ english: String) -> String {
    AppLanguage.current == .english ? english : spanish
}
