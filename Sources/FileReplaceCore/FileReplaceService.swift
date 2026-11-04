import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Un par «buscar → reemplazar». Una búsqueda puede llevar varios y todos se
/// aplican en una sola pasada sobre el contenido original del archivo.
public struct ReplacementRule: Equatable, Hashable, Codable, Sendable {
    public var find: String
    public var replace: String

    public init(find: String, replace: String) {
        self.find = find
        self.replace = replace
    }
}

/// Una aparición concreta de una regla dentro de un archivo. Los desplazamientos
/// están en unidades UTF-16 (los de `NSString`), sobre el contenido leído al
/// buscar; `SearchHit.contentDigest` permite comprobar que no ha cambiado.
public struct MatchOccurrence: Identifiable, Equatable, Sendable {
    /// Posición de la aparición dentro del archivo (0, 1, 2…), estable mientras
    /// el contenido no cambie.
    public let id: Int
    public let ruleIndex: Int
    public let utf16Offset: Int
    public let utf16Length: Int
    /// Línea (desde 1) donde empieza la aparición.
    public let line: Int
    /// Texto de la línea antes y después de la aparición, recortado y sin saltos.
    public let prefix: String
    public let matchedText: String
    public let suffix: String

    public init(
        id: Int,
        ruleIndex: Int,
        utf16Offset: Int,
        utf16Length: Int,
        line: Int,
        prefix: String,
        matchedText: String,
        suffix: String
    ) {
        self.id = id
        self.ruleIndex = ruleIndex
        self.utf16Offset = utf16Offset
        self.utf16Length = utf16Length
        self.line = line
        self.prefix = prefix
        self.matchedText = matchedText
        self.suffix = suffix
    }
}

public struct SearchHit: Identifiable, Equatable, Sendable {
    public let id: String
    public let fileURL: URL
    public let relativePath: String
    public let count: Int
    public let preview: String
    /// Apariciones de las reglas de la búsqueda, en orden de posición y sin solaparse.
    public let occurrences: [MatchOccurrence]
    /// Huella del contenido leído al buscar, para detectar cambios antes de escribir.
    public let contentDigest: String

    public init(
        fileURL: URL,
        relativePath: String,
        count: Int,
        preview: String,
        occurrences: [MatchOccurrence] = [],
        contentDigest: String = ""
    ) {
        self.id = fileURL.path
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.count = count
        self.preview = preview
        self.occurrences = occurrences
        self.contentDigest = contentDigest
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
    public let fileURL: URL?
    /// Huella del contenido escrito; el historial la usa para comprobar, antes de
    /// restaurar, que nadie ha tocado el archivo después del reemplazo.
    public let writtenDigest: String

    public init(replacements: Int, backupURL: URL, fileURL: URL? = nil, writtenDigest: String = "") {
        self.replacements = replacements
        self.backupURL = backupURL
        self.fileURL = fileURL
        self.writtenDigest = writtenDigest
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
    case fileChangedSinceSearch(String)
    case nothingSelected(String)
    case backupMissing(String)
    case fileChangedSinceReplacement(String)

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
        case .fileChangedSinceSearch(let path):
            return "El archivo cambió después de la búsqueda; vuelve a buscar antes de reemplazar: \(path)"
        case .nothingSelected(let path):
            return "No hay ninguna coincidencia marcada en el archivo: \(path)"
        case .backupMissing(let path):
            return "La copia de seguridad ya no existe; no se puede restaurar: \(path)"
        case .fileChangedSinceReplacement(let path):
            return "El archivo se ha modificado después del reemplazo; restaurarlo perdería esos cambios: \(path)"
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
        try search(
            directoryURL: directoryURL,
            namePattern: namePattern,
            rules: [ReplacementRule(find: searchText, replace: "")],
            recursive: recursive,
            maxDepth: maxDepth,
            maxResults: maxResults,
            maxFileSizeBytes: maxFileSizeBytes
        )
    }

    /// Busca a la vez todas las `rules` en los archivos de `directoryURL`. Las
    /// reglas con el texto de búsqueda vacío se ignoran. Cada `SearchHit` lleva
    /// sus apariciones (`occurrences`) para revisarlas y reemplazarlas una a una.
    public func search(
        directoryURL: URL?,
        namePattern: String = "",
        rules: [ReplacementRule],
        recursive: Bool,
        maxDepth: Int,
        maxResults: Int = FileReplaceService.defaultMaxResults,
        maxFileSizeBytes: Int = FileReplaceService.defaultMaxFileSizeBytes
    ) throws -> SearchReport {
        guard let directoryURL else { throw FileReplaceError.missingDirectory }

        let cleanPattern = namePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard rules.contains(where: { !$0.find.isEmpty }) else { throw FileReplaceError.emptySearch }

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
                let occurrences = Self.occurrences(of: rules, in: content)

                if let first = occurrences.first {
                    hits.append(
                        SearchHit(
                            fileURL: fileURL,
                            relativePath: relativePath(for: fileURL, from: directoryURL),
                            count: occurrences.count,
                            preview: "\(first.prefix)>>>>\(first.matchedText)<<<<\(first.suffix)",
                            occurrences: occurrences,
                            contentDigest: Self.digest(of: content)
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

    /// Lee el contenido completo de un archivo de texto para previsualizarlo.
    /// Reutiliza las mismas validaciones que `search` (UTF-8 estricto, tamaño máximo),
    /// para que un archivo excluido de los resultados por tamaño o codificación
    /// tampoco pueda previsualizarse con un límite distinto.
    public func readFullContent(
        at fileURL: URL,
        maxBytes: Int = FileReplaceService.defaultMaxFileSizeBytes
    ) throws -> String {
        try readTextFile(fileURL, maxBytes: maxBytes)
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

    /// Aplica `rules` solo en las apariciones de `hit` que no estén en
    /// `excludedOccurrenceIDs`, en una sola pasada sobre el contenido original:
    /// el texto ya reemplazado no vuelve a buscarse, así que «A→B» y «B→C» no se
    /// encadenan. Falla con `.fileChangedSinceSearch` si el archivo cambió desde
    /// la búsqueda, para no escribir en posiciones que ya no corresponden.
    public func replace(
        in hit: SearchHit,
        rules: [ReplacementRule],
        excludingOccurrences excludedOccurrenceIDs: Set<Int> = []
    ) throws -> ReplacementResult {
        let content = try readTextFile(hit.fileURL, maxBytes: Self.defaultMaxFileSizeBytes)
        guard Self.digest(of: content) == hit.contentDigest else {
            throw FileReplaceError.fileChangedSinceSearch(hit.fileURL.path)
        }

        let selected = hit.occurrences.filter { !excludedOccurrenceIDs.contains($0.id) }
        guard !selected.isEmpty else { throw FileReplaceError.nothingSelected(hit.fileURL.path) }

        guard fileManager.isWritableFile(atPath: hit.fileURL.path) else {
            throw FileReplaceError.notWritable(hit.fileURL.path)
        }

        let utf16 = content.utf16
        var newContent = ""
        var cursor = utf16.startIndex
        for occurrence in selected.sorted(by: { $0.utf16Offset < $1.utf16Offset }) {
            guard rules.indices.contains(occurrence.ruleIndex) else {
                throw FileReplaceError.fileChangedSinceSearch(hit.fileURL.path)
            }
            let start = utf16.index(utf16.startIndex, offsetBy: occurrence.utf16Offset)
            let end = utf16.index(start, offsetBy: occurrence.utf16Length)
            newContent += String(content[cursor..<start])
            newContent += rules[occurrence.ruleIndex].replace
            cursor = end
        }
        newContent += String(content[cursor...])

        let backupURL = try createBackup(for: hit.fileURL)

        do {
            try newContent.write(to: hit.fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw FileReplaceError.writeFailed(hit.fileURL.path)
        }

        return ReplacementResult(
            replacements: selected.count,
            backupURL: backupURL,
            fileURL: hit.fileURL,
            writtenDigest: Self.digest(of: newContent)
        )
    }

    /// Devuelve un archivo a su copia de seguridad, solo si sigue exactamente
    /// como lo dejó Replacer: si alguien lo editó después, restaurar borraría ese
    /// trabajo y se informa con `.fileChangedSinceReplacement`. La copia de
    /// seguridad se conserva.
    public func restore(_ entry: ReplacementBatch.Entry) throws {
        let fileURL = entry.fileURL
        let backupURL = entry.backupURL

        guard fileManager.isRegularFile(backupURL) else {
            throw FileReplaceError.backupMissing(backupURL.path)
        }

        let current = try readTextFile(fileURL, maxBytes: Self.defaultMaxFileSizeBytes)
        guard Self.digest(of: current) == entry.writtenDigest else {
            throw FileReplaceError.fileChangedSinceReplacement(fileURL.path)
        }

        guard fileManager.isWritableFile(atPath: fileURL.path) else {
            throw FileReplaceError.notWritable(fileURL.path)
        }

        let original: Data
        do {
            original = try Data(contentsOf: backupURL)
        } catch {
            throw FileReplaceError.readFailed(backupURL.path)
        }

        do {
            try original.write(to: fileURL, options: .atomic)
        } catch {
            throw FileReplaceError.writeFailed(fileURL.path)
        }
    }

    /// Localiza todas las apariciones de `rules` en `content`. Cada regla se
    /// busca sin solapes consigo misma; entre reglas, gana la aparición que
    /// empieza antes y, a igual posición, la regla que va primero en la lista.
    static func occurrences(of rules: [ReplacementRule], in content: String) -> [MatchOccurrence] {
        var candidates: [(range: Range<String.Index>, ruleIndex: Int)] = []
        for (ruleIndex, rule) in rules.enumerated() where !rule.find.isEmpty {
            var searchStart = content.startIndex
            while let range = content.range(of: rule.find, range: searchStart..<content.endIndex) {
                candidates.append((range, ruleIndex))
                searchStart = range.upperBound
            }
        }

        candidates.sort {
            $0.range.lowerBound != $1.range.lowerBound
                ? $0.range.lowerBound < $1.range.lowerBound
                : $0.ruleIndex < $1.ruleIndex
        }

        var result: [MatchOccurrence] = []
        var lastEnd = content.startIndex
        var line = 1
        var lineCountedUpTo = content.startIndex

        for candidate in candidates where candidate.range.lowerBound >= lastEnd {
            let range = candidate.range
            line += content[lineCountedUpTo..<range.lowerBound].reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
            lineCountedUpTo = range.lowerBound

            let lineStart = content[..<range.lowerBound].lastIndex(of: "\n").map { content.index(after: $0) } ?? content.startIndex
            let lineEnd = content[range.upperBound...].firstIndex(of: "\n") ?? content.endIndex

            result.append(
                MatchOccurrence(
                    id: result.count,
                    ruleIndex: candidate.ruleIndex,
                    utf16Offset: content.utf16.distance(from: content.utf16.startIndex, to: range.lowerBound),
                    utf16Length: content.utf16.distance(from: range.lowerBound, to: range.upperBound),
                    line: line,
                    prefix: String(content[lineStart..<range.lowerBound].suffix(Self.occurrenceContext)),
                    matchedText: String(content[range]).replacingOccurrences(of: "\n", with: "⏎"),
                    suffix: String(content[range.upperBound..<lineEnd].prefix(Self.occurrenceContext))
                )
            )
            lastEnd = range.upperBound
        }

        return result
    }

    /// Caracteres de contexto que se guardan a cada lado de una aparición.
    static let occurrenceContext = 60

    /// Huella FNV-1a de 64 bits del contenido en UTF-8. Estable entre ejecuciones
    /// (a diferencia de `hashValue`), así que también sirve para el historial.
    public static func digest(of content: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in content.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
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
}
