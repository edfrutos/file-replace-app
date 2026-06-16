import Foundation

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

    public init(filesScanned: Int, hits: [SearchHit], filesWithoutMatch: [String]) {
        self.filesScanned = filesScanned
        self.hits = hits
        self.filesWithoutMatch = filesWithoutMatch
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
    case emptyFilename
    case emptySearch
    case fileNotFound(String)
    case noMatches
    case unsupportedFileType(String)
    case readFailed(String)
    case backupFailed(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingDirectory:
            return "Selecciona un directorio."
        case .invalidDirectory(let path):
            return "El directorio no existe o no es accesible: \(path)"
        case .emptyFilename:
            return "El nombre de archivo no puede estar vacío."
        case .emptySearch:
            return "La cadena de búsqueda no puede estar vacía."
        case .fileNotFound(let filename):
            return "No se encontró ningún archivo llamado \(filename)."
        case .noMatches:
            return "No se encontraron coincidencias en los archivos localizados."
        case .unsupportedFileType(let path):
            return "El archivo no parece ser texto UTF-8 editable: \(path)"
        case .readFailed(let path):
            return "No se pudo leer el archivo: \(path)"
        case .backupFailed(let path):
            return "No se pudo crear una copia de seguridad del archivo: \(path)"
        case .writeFailed(let path):
            return "No se pudo escribir en el archivo: \(path)"
        }
    }
}

public final class FileReplaceService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func search(
        directoryURL: URL?,
        filename: String,
        searchText: String,
        recursive: Bool,
        maxDepth: Int,
        maxResults: Int = 50
    ) throws -> SearchReport {
        guard let directoryURL else { throw FileReplaceError.missingDirectory }

        let cleanFilename = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanFilename.isEmpty else { throw FileReplaceError.emptyFilename }
        guard !searchText.isEmpty else { throw FileReplaceError.emptySearch }

        var isDirectory: ObjCBool = false
        let directoryPath = directoryURL.path
        guard fileManager.fileExists(atPath: directoryPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FileReplaceError.invalidDirectory(directoryPath)
        }

        let fileURLs = findFiles(
            directoryURL: directoryURL,
            filename: cleanFilename,
            recursive: recursive,
            maxDepth: max(1, maxDepth),
            maxResults: maxResults
        )

        guard !fileURLs.isEmpty else { throw FileReplaceError.fileNotFound(cleanFilename) }

        var hits: [SearchHit] = []
        var noMatchFiles: [String] = []

        for fileURL in fileURLs {
            let content = try readTextFile(fileURL)
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
        }

        guard !hits.isEmpty else { throw FileReplaceError.noMatches }

        return SearchReport(
            filesScanned: fileURLs.count,
            hits: hits,
            filesWithoutMatch: noMatchFiles
        )
    }

    public func replace(in hit: SearchHit, searchText: String, replacementText: String) throws -> ReplacementResult {
        guard !searchText.isEmpty else { throw FileReplaceError.emptySearch }

        let content = try readTextFile(hit.fileURL)
        let count = content.nonOverlappingCount(of: searchText)
        guard count > 0 else { throw FileReplaceError.noMatches }

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
        filename: String,
        recursive: Bool,
        maxDepth: Int,
        maxResults: Int
    ) -> [URL] {
        if !recursive {
            let candidate = directoryURL.appendingPathComponent(filename)
            return fileManager.isRegularFile(candidate) ? [candidate] : []
        }

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var matches: [URL] = []
        let baseDepth = directoryURL.standardizedFileURL.pathComponents.count

        for case let fileURL as URL in enumerator {
            let currentDepth = fileURL.standardizedFileURL.pathComponents.count - baseDepth

            if currentDepth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            if fileURL.lastPathComponent == filename, fileManager.isRegularFile(fileURL) {
                matches.append(fileURL)
            }

            if matches.count >= maxResults {
                break
            }
        }

        return matches
    }

    private func readTextFile(_ fileURL: URL) throws -> String {
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
