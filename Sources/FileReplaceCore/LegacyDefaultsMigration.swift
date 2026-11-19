import Foundation

/// Trae los ajustes guardados por los DMG anteriores a la 1.4.1, que usaban el
/// identificador `local.replacer.app`, al dominio del identificador actual
/// (`com.edefrutos.Replacer`, el mismo que la versión del Mac App Store).
///
/// Solo tiene sentido en la versión DMG, que no lleva sandbox: con sandbox la app
/// no puede leer el dominio antiguo y la migración no encuentra nada que copiar.
public enum LegacyDefaultsMigration {
    public static let legacyBundleIdentifier = "local.replacer.app"

    /// Marca guardada en el dominio nuevo para no repetir la migración.
    public static let completedKey = "replacerLegacyDefaultsMigrated"

    /// Claves que la app guarda: recetas, apariencia e idioma.
    public static let migratedKeys = ["replacerRecipes", "replacerAppearanceMode", "AppleLanguages"]

    /// Copia una sola vez las claves del dominio antiguo que falten en el nuevo.
    /// Nunca sobrescribe un valor ya guardado con el identificador actual.
    ///
    /// - Parameters:
    ///   - legacyDomain: el dominio persistente de `local.replacer.app`, si existe.
    ///   - defaults: los ajustes del identificador actual.
    ///   - domainName: el nombre de ese dominio. Hace falta para distinguir lo que
    ///     guarda la app de lo que hereda del dominio global, como `AppleLanguages`.
    /// - Returns: las claves copiadas.
    @discardableResult
    public static func migrate(
        legacyDomain: [String: Any]?,
        into defaults: UserDefaults,
        domainName: String
    ) -> [String] {
        guard !defaults.bool(forKey: completedKey) else { return [] }
        defer { defaults.set(true, forKey: completedKey) }

        guard let legacyDomain else { return [] }
        let current = defaults.persistentDomain(forName: domainName) ?? [:]

        var copied: [String] = []
        for key in migratedKeys where current[key] == nil {
            guard let value = legacyDomain[key] else { continue }
            defaults.set(value, forKey: key)
            copied.append(key)
        }
        return copied
    }
}
