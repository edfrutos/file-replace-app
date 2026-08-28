import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public struct SearchHit: Identifiable, Equatable, Sendable {
    public let id: String
    public let fileURL: URL
    public let relativePath: String
    public let count: Int
    public let preview: String

    public init(fileURL: URL, relativePath: String, count: Int, preview: String) {
        self.id = fileURL.path
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.count = count
        self.preview = preview
    }
}

public struct SearchReport: Equatable, Sendable {
    public let filesScanned: Int
    public let hits: [SearchHit]
    public let filesWithoutMatch: [String]
    public let skippedFiles: [String]
    public let reachedResultLimit: Bool

    public init(
        filesScanned: Int,
        hits: [SearchHit],
        filesWithoutMatch: [String],
        skippedFiles: [String] = [],
        reachedResultLimit: Bool = false
    ) {
        self.filesScanned = filesScanned
        self.hits = hits
        self.filesWithoutMatch = filesWithoutMatch
        self.skippedFiles = skippedFiles
        self.reachedResultLimit = reachedResultLimit
    }
}

public struct ReplacementResult: Equatable, Sendable {
    public let replacements: Int
    public let backupURL: URL

    public init(replacements: Int, backupURL: URL) {
        self.replacements = replacements
        self.backupURL = backupURL
    }
}

public enum FileReplaceError: LocalizedError, Equatable {
    case missingDirectory
    case invalidDirectory(String)
    case emptySearch
    case noFilesFound(String)
    case noMatches
    case unsupportedFileType(String)
    case fileTooLarge(String)
    case readFailed(String)
    case backupFailed(String)
    case notWritable(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingDirectory:
            return "Selecciona un directorio."
        case .invalidDirectory(let path):
            return "El directorio no existe o no es accesible: \(path)"
        case .emptySearch:
            return "La cadena de búsqueda no puede estar vacía."
        case .noFilesFound(let scope):
            return "No se encontró ningún archivo en el alcance indicado: \(scope)"
        case .noMatches:
            return "No se encontraron coincidencias en los archivos revisados."
        case .unsupportedFileType(let path):
            return "El archivo no parece ser texto UTF-8 editable: \(path)"
        case .fileTooLarge(let path):
            return "El archivo supera el tamaño máximo admitido y se omitió: \(path)"
        case .readFailed(let path):
            return "No se pudo leer el archivo: \(path)"
        case .backupFailed(let path):
            return "No se pudo crear una copia de seguridad del archivo: \(path)"
        case .notWritable(let path):
            return "El archivo es de solo lectura y no se puede modificar: \(path)"
        case .writeFailed(let path):
            return "No se pudo escribir en el archivo: \(path)"
        }
    }
}

public final class FileReplaceService: @unchecked Sendable {
    /// Tamaño máximo por archivo que se lee durante la búsqueda. Los archivos
    /// mayores se omiten para no penalizar el rastreo de árboles grandes.
    public static let defaultMaxFileSizeBytes = 5 * 1024 * 1024

    /// Número máximo de archivos que devuelve una búsqueda ampliada.
    public static let defaultMaxResults = 1000

    /// Directorios que nunca se recorren en búsqueda recursiva (control de
    /// versiones, artefactos de build y entornos de dependencias).
    public static let prunedDirectoryNames: Set<String> = [
        ".git", ".hg", ".svn", ".build", ".swiftpm", "DerivedData",
        "node_modules", ".venv", "venv", "__pycache__", ".mypy_cache", ".pytest_cache"
    ]

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Busca `searchText` en los archivos de `directoryURL`.
    ///
    /// - Parameters:
    ///   - namePattern: patrón glob opcional sobre el nombre del archivo
    ///     (`*.js`, `config*`, `.env*`). Vacío = todos los archivos del alcance.
    ///   - recursive: si es `true`, desciende por subdirectorios hasta `maxDepth` niveles.
    ///   - maxFileSizeBytes: los archivos más grandes se añaden a `skippedFiles`.
    public func search(
        directoryURL: URL?,
        namePattern: String = "",
        searchText: String,
        recursive: Bool,
        maxDepth: Int,
        maxResults: Int = FileReplaceService.defaultMaxResults,
        maxFileSizeBytes: Int = FileReplaceService.defaultMaxFileSizeBytes
    ) throws -> SearchReport {
        guard let directoryURL else { throw FileReplaceError.missingDirectory }

        let cleanPattern = namePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { throw FileReplaceError.emptySearch }

        var isDirectory: ObjCBool = false
        let directoryPath = directoryURL.path
        guard fileManager.fileExists(atPath: directoryPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FileReplaceError.invalidDirectory(directoryPath)
        }

        let found = findFiles(
            directoryURL: directoryURL,
            pattern: cleanPattern,
            recursive: recursive,
            maxDepth: max(1, maxDepth),
            maxResults: max(1, maxResults)
        )

        guard !found.urls.isEmpty else {
            throw FileReplaceError.noFilesFound(cleanPattern.isEmpty ? directoryPath : cleanPattern)
        }

        var hits: [SearchHit] = []
        var noMatchFiles: [String] = []
        var skippedFiles: [String] = []

        for fileURL in found.urls {
            do {
                let content = try readTextFile(fileURL, maxBytes: maxFileSizeBytes)
                let count = content.nonOverlappingCount(of: searchText)

                if count > 0 {
                    hits.append(
                        SearchHit(
                            fileURL: fileURL,
                            relativePath: relativePath(for: fileURL, from: directoryURL),
                            count: count,
                            preview: content.preview(around: searchText, context: 90)
                        )
                    )
                } else {
                    noMatchFiles.append(fileURL.path)
                }
            } catch {
                skippedFiles.append(fileURL.path)
            }
        }

        guard !hits.isEmpty else { throw FileReplaceError.noMatches }

        return SearchReport(
            filesScanned: found.urls.count,
            hits: hits,
            filesWithoutMatch: noMatchFiles,
            skippedFiles: skippedFiles,
            reachedResultLimit: found.reachedLimit
        )
    }

    public func replace(in hit: SearchHit, searchText: String, replacementText: String) throws -> ReplacementResult {
        guard !searchText.isEmpty else { throw FileReplaceError.emptySearch }

        let content = try readTextFile(hit.fileURL, maxBytes: Self.defaultMaxFileSizeBytes)
        let count = content.nonOverlappingCount(of: searchText)
        guard count > 0 else { throw FileReplaceError.noMatches }

        guard fileManager.isWritableFile(atPath: hit.fileURL.path) else {
            throw FileReplaceError.notWritable(hit.fileURL.path)
        }

        let newContent = content.replacingOccurrences(of: searchText, with: replacementText)
        let backupURL = try createBackup(for: hit.fileURL)

        do {
            try newContent.write(to: hit.fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw FileReplaceError.writeFailed(hit.fileURL.path)
        }

        return ReplacementResult(replacements: count, backupURL: backupURL)
    }

    private func findFiles(
        directoryURL: URL,
        pattern: String,
        recursive: Bool,
        maxDepth: Int,
        maxResults: Int
    ) -> (urls: [URL], reachedLimit: Bool) {
        var matches: [URL] = []

        if !recursive {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: []
            ) else {
                return ([], false)
            }

            for fileURL in entries.sorted(by: { $0.path < $1.path }) {
                guard fileManager.isRegularFile(fileURL) else { continue }

                let name = fileURL.lastPathComponent
                guard !isBackupArtifact(name) else { continue }
                guard matchesPattern(name, pattern: pattern) else { continue }

                matches.append(fileURL)
                if matches.count >= maxResults { return (matches, true) }
            }

            return (matches, false)
        }

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return ([], false)
        }

        let baseDepth = directoryURL.standardizedFileURL.pathComponents.count

        for case let fileURL as URL in enumerator {
            let currentDepth = fileURL.standardizedFileURL.pathComponents.count - baseDepth

            if currentDepth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])

            if values?.isDirectory == true {
                if Self.prunedDirectoryNames.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values?.isRegularFile == true else { continue }

            let name = fileURL.lastPathComponent
            guard !isBackupArtifact(name) else { continue }
            guard matchesPattern(name, pattern: pattern) else { continue }

            matches.append(fileURL)
            if matches.count >= maxResults {
                return (matches, true)
            }
        }

        return (matches, false)
    }

    /// Los backups que genera Replacer no deben ser objetivo de búsqueda ni de reemplazo.
    private func isBackupArtifact(_ name: String) -> Bool {
        name.range(of: ".replacer-backup") != nil
    }

    /// Coincidencia glob POSIX sobre el nombre del archivo. Patrón vacío = acepta todo.
    private func matchesPattern(_ name: String, pattern: String) -> Bool {
        guard !pattern.isEmpty else { return true }

        return pattern.withCString { patternPointer in
            name.withCString { namePointer in
                fnmatch(patternPointer, namePointer, 0) == 0
            }
        }
    }

    private func readTextFile(_ fileURL: URL, maxBytes: Int) throws -> String {
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let size = attributes[.size] as? Int,
           size > maxBytes {
            throw FileReplaceError.fileTooLarge(fileURL.path)
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        } catch {
            throw FileReplaceError.readFailed(fileURL.path)
        }

        if data.contains(0) {
            throw FileReplaceError.unsupportedFileType(fileURL.path)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw FileReplaceError.unsupportedFileType(fileURL.path)
        }

        return content
    }

    private func createBackup(for fileURL: URL) throws -> URL {
        let directoryURL = fileURL.deletingLastPathComponent()
        let baseName = "\(fileURL.lastPathComponent).replacer-backup"
        var candidate = directoryURL.appendingPathComponent(baseName)
        var suffix = 1

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directoryURL.appendingPathComponent("\(baseName)-\(suffix)")
            suffix += 1
        }

        do {
            try fileManager.copyItem(at: fileURL, to: candidate)
        } catch {
            throw FileReplaceError.backupFailed(fileURL.path)
        }

        return candidate
    }

    private func relativePath(for fileURL: URL, from directoryURL: URL) -> String {
        let base = directoryURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(base) else { return fileURL.lastPathComponent }

        let start = filePath.index(filePath.startIndex, offsetBy: base.count)
        return String(filePath[start...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

private extension FileManager {
    func isRegularFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue
    }
}

private extension String {
    func nonOverlappingCount(of needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }

        var count = 0
        var searchStart = startIndex

        while let range = range(of: needle, range: searchStart..<endIndex) {
            count += 1
            searchStart = range.upperBound
        }

        return count
    }

    func preview(around needle: String, context: Int) -> String {
        guard let range = range(of: needle) else { return "" }

        let lower = index(range.lowerBound, offsetBy: -context, limitedBy: startIndex) ?? startIndex
        let upper = index(range.upperBound, offsetBy: context, limitedBy: endIndex) ?? endIndex
        let snippet = String(self[lower..<upper]).replacingOccurrences(of: "\n", with: " ")

        return snippet.replacingOccurrences(of: needle, with: ">>>>\(needle)<<<<")
    }
}
