import Foundation

/// Lista de pares «buscar → reemplazar» con nombre, para guardarla y reutilizarla
/// (por ejemplo, «Migrar dominio»).
public struct ReplacementRecipe: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var rules: [ReplacementRule]

    public init(id: UUID = UUID(), name: String, rules: [ReplacementRule]) {
        self.id = id
        self.name = name
        self.rules = rules
    }
}

/// Importa pares «buscar → reemplazar» desde texto CSV/TSV: una fila por par,
/// primera columna el texto a buscar y segunda el de reemplazo.
public enum RuleListParser {
    /// Detecta el separador (tabulador, punto y coma —el que usa Excel en
    /// español— o coma) a partir de la primera línea, admite campos entre
    /// comillas con `""` como comilla literal y saltos de línea dentro, e ignora
    /// filas vacías, filas sin texto a buscar y una cabecera del tipo
    /// «buscar;reemplazar» o «find,replace».
    public static func parse(_ text: String) -> [ReplacementRule] {
        let content = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let separator = detectSeparator(in: content)

        var rows = parseRows(content, separator: separator)
        if let first = rows.first, isHeader(first) {
            rows.removeFirst()
        }

        return rows.compactMap { fields in
            guard let find = fields.first, !find.isEmpty else { return nil }
            return ReplacementRule(find: find, replace: fields.count > 1 ? fields[1] : "")
        }
    }

    private static func detectSeparator(in content: String) -> Character {
        let firstLine = content.prefix { $0 != "\n" && $0 != "\r" }
        if firstLine.contains("\t") { return "\t" }
        let semicolons = firstLine.filter { $0 == ";" }.count
        let commas = firstLine.filter { $0 == "," }.count
        return semicolons > commas ? ";" : ","
    }

    private static func isHeader(_ fields: [String]) -> Bool {
        let headers: Set<String> = ["buscar", "find", "search", "texto a buscar", "origen", "from"]
        guard let first = fields.first else { return false }
        return headers.contains(first.trimmingCharacters(in: .whitespaces).lowercased())
    }

    private static func parseRows(_ content: String, separator: Character) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = content.makeIterator()
        var pending: Character? = nil

        func endField() {
            fields.append(field)
            field = ""
        }

        func endRow() {
            endField()
            if !(fields.count == 1 && fields[0].isEmpty) {
                rows.append(fields)
            }
            fields = []
        }

        while let character = pending ?? iterator.next() {
            pending = nil

            if inQuotes {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = next
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }

            switch character {
            case "\"" where field.isEmpty:
                inQuotes = true
            case separator:
                endField()
            case "\n", "\r", "\r\n":
                endRow()
            default:
                field.append(character)
            }
        }

        if !field.isEmpty || !fields.isEmpty {
            endRow()
        }

        return rows
    }
}
