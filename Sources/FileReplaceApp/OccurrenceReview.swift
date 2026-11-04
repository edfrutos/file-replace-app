import AppKit
import FileReplaceCore
import SwiftUI

/// Lista de las apariciones de un resultado, cada una con su línea y el
/// cambio antes → después, para incluirlas o excluirlas una a una.
struct OccurrenceList: View {
    let hit: SearchHit
    let excluded: Set<Int>
    let replacement: (MatchOccurrence) -> String
    let onToggle: (Int) -> Void
    let onIncludeAll: () -> Void
    let onExcludeAll: () -> Void

    /// Las filas que se dibujan; con miles de apariciones la lista se volvería
    /// lenta. Las que no se muestran se reemplazan igual salvo que se excluyan todas.
    static let maxVisibleRows = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tr("\(hit.count - excluded.count) de \(hit.count) incluidas", "\(hit.count - excluded.count) of \(hit.count) included"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReplacerTheme.muted)

                Spacer()

                Button(tr("Incluir todas", "Include all"), action: onIncludeAll)
                    .disabled(excluded.isEmpty)
                Button(tr("Excluir todas", "Exclude all"), action: onExcludeAll)
                    .disabled(excluded.count == hit.count)
            }
            .buttonStyle(.borderless)
            .font(.caption)

            ForEach(hit.occurrences.prefix(Self.maxVisibleRows)) { occurrence in
                OccurrenceRow(
                    occurrence: occurrence,
                    isIncluded: !excluded.contains(occurrence.id),
                    replacement: replacement(occurrence),
                    onToggle: { onToggle(occurrence.id) }
                )
            }

            if hit.occurrences.count > Self.maxVisibleRows {
                Text(tr("Se muestran las primeras \(Self.maxVisibleRows) de \(hit.count). Las demás se reemplazarán salvo que pulses «Excluir todas».", "Showing the first \(Self.maxVisibleRows) of \(hit.count). The rest will be replaced unless you click “Exclude all”."))
                    .font(.caption2)
                    .foregroundStyle(ReplacerTheme.muted)
            }
        }
        .padding(12)
        .background(ReplacerTheme.tint)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OccurrenceRow: View {
    let occurrence: MatchOccurrence
    let isIncluded: Bool
    let replacement: String
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: isIncluded ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isIncluded ? ReplacerTheme.teal : ReplacerTheme.muted)

                Text("L\(occurrence.line)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ReplacerTheme.muted)
                    .frame(minWidth: 38, alignment: .leading)

                Text(diff)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isIncluded ? tr("Se reemplazará. Pulsa para excluirla.", "Will be replaced. Click to exclude it.") : tr("Excluida: se dejará como está. Pulsa para incluirla.", "Excluded: it will be left as is. Click to include it."))
    }

    /// «…contexto [antes tachado][después] contexto…»; si está excluida solo
    /// se muestra el texto original.
    private var diff: AttributedString {
        var before = AttributedString(Self.trimmedPrefix(occurrence.prefix))
        before.foregroundColor = ReplacerTheme.ink.opacity(0.75)

        var matched = AttributedString(occurrence.matchedText)
        var result = before

        if isIncluded {
            matched.strikethroughStyle = .single
            matched.foregroundColor = Color(nsColor: .systemRed)
            result += matched

            var after = AttributedString(replacement)
            after.foregroundColor = ReplacerTheme.teal
            after.inlinePresentationIntent = .stronglyEmphasized
            result += after
        } else {
            matched.foregroundColor = ReplacerTheme.ink
            matched.backgroundColor = Color(nsColor: .systemYellow).opacity(0.35)
            result += matched
        }

        var rest = AttributedString(occurrence.suffix)
        rest.foregroundColor = ReplacerTheme.ink.opacity(0.75)
        result += rest
        return result
    }

    /// Quita la sangría inicial para que el cambio quede a la vista.
    private static func trimmedPrefix(_ prefix: String) -> String {
        String(prefix.drop { $0 == " " || $0 == "\t" })
    }
}
