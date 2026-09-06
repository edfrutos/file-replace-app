import Foundation

/// Fuente única de la versión de la app. El script de empaquetado
/// (`scripts/build-macos-app.sh`) lee esta cadena para `CFBundleShortVersionString`.
///
/// Se mantiene como constante Swift (y no como recurso del bundle) para que la app
/// no dependa de `Bundle.module`, que falla si el `.app` no incluye el bundle de
/// recursos de SwiftPM.
public enum ReplacerBuildInfo {
    public static let version = "1.3.0"

    /// Versión analizada; si la cadena fuese inválida cae a `0.0.0` en lugar de abortar.
    public static var appVersion: AppVersion {
        AppVersion(version) ?? AppVersion("0.0.0")!
    }
}
