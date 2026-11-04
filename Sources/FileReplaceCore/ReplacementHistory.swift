import Foundation

/// Un reemplazo confirmado por el usuario: qué pares se aplicaron, en qué
/// carpeta y qué archivos se escribieron, con su copia de seguridad.
public struct ReplacementBatch: Identifiable, Equatable, Codable, Sendable {
    public struct Entry: Identifiable, Equatable, Codable, Sendable {
        public var id: UUID
        public var filePath: String
        public var backupPath: String
        public var replacements: Int
        /// Huella del contenido que escribió Replacer. Si el archivo ya no la
        /// tiene, alguien lo ha editado después y restaurar perdería esos cambios.
        public var writtenDigest: String
        public var restoredAt: Date?

        public init(
            id: UUID = UUID(),
            filePath: String,
            backupPath: String,
            replacements: Int,
            writtenDigest: String,
            restoredAt: Date? = nil
        ) {
            self.id = id
            self.filePath = filePath
            self.backupPath = backupPath
            self.replacements = replacements
            self.writtenDigest = writtenDigest
            self.restoredAt = restoredAt
        }

        public init?(result: ReplacementResult) {
            guard let fileURL = result.fileURL else { return nil }
            self.init(
                filePath: fileURL.path,
                backupPath: result.backupURL.path,
                replacements: result.replacements,
                writtenDigest: result.writtenDigest
            )
        }

        public var fileURL: URL { URL(fileURLWithPath: filePath) }
        public var backupURL: URL { URL(fileURLWithPath: backupPath) }
    }

    public var id: UUID
    public var date: Date
    public var directoryPath: String
    /// Marcador con permiso de acceso a la carpeta (lo crea la app). Con sandbox,
    /// sin él no se puede volver a escribir en los archivos tras reiniciar.
    public var directoryBookmark: Data?
    public var rules: [ReplacementRule]
    public var entries: [Entry]

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        directoryPath: String,
        directoryBookmark: Data? = nil,
        rules: [ReplacementRule],
        entries: [Entry]
    ) {
        self.id = id
        self.date = date
        self.directoryPath = directoryPath
        self.directoryBookmark = directoryBookmark
        self.rules = rules
        self.entries = entries
    }

    public var totalReplacements: Int {
        entries.reduce(0) { $0 + $1.replacements }
    }

    public var pendingEntries: [Entry] {
        entries.filter { $0.restoredAt == nil }
    }
}

/// Guarda el historial de reemplazos en un JSON, el más reciente primero.
public struct ReplacementHistoryStore: Sendable {
    public static let maxBatches = 50

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Un historial ausente o ilegible se trata como vacío: perderlo no debe
    /// impedir buscar ni reemplazar.
    public func load() -> [ReplacementBatch] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? Self.decoder.decode([ReplacementBatch].self, from: data)) ?? []
    }

    public func save(_ batches: [ReplacementBatch]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(Array(batches.prefix(Self.maxBatches)))
        try data.write(to: fileURL, options: .atomic)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
