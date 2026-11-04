import AppKit
import FileReplaceCore
import SwiftUI

/// Editor de pares «buscar → reemplazar» de la barra lateral, con el menú de
/// recetas guardadas e importación desde CSV.
struct RulesEditor: View {
    @ObservedObject var viewModel: FileReplaceViewModel

    private var isSinglePair: Bool {
        viewModel.rules.count == 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isSinglePair ? tr("Buscar y reemplazar", "Find and replace") : tr("\(viewModel.rules.count) pares buscar → reemplazar", "\(viewModel.rules.count) find → replace pairs"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ReplacerTheme.muted)

                Spacer()

                RecipesMenu(viewModel: viewModel)
            }

            ForEach(Array(viewModel.rules.enumerated()), id: \.element.id) { index, rule in
                RulePairEditor(
                    number: index + 1,
                    find: viewModel.findBinding(for: rule.id),
                    replace: viewModel.replaceBinding(for: rule.id),
                    isSinglePair: isSinglePair,
                    onRemove: { viewModel.removeRule(rule.id) }
                )
            }

            Button {
                viewModel.addRule()
            } label: {
                Label(tr("Añadir par", "Add pair"), systemImage: "plus.circle")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(ReplacerTheme.blue)
            .help(tr("Busca y reemplaza varios textos a la vez, en una sola pasada", "Find and replace several texts at once, in a single pass"))
        }
    }
}

private struct RulePairEditor: View {
    let number: Int
    @Binding var find: String
    @Binding var replace: String
    let isSinglePair: Bool
    let onRemove: () -> Void

    var body: some View {
        if isSinglePair {
            fields(editorHeight: 60)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tr("Par \(number)", "Pair \(number)"))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(ReplacerTheme.ink)
                    Spacer()
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help(tr("Quitar este par", "Remove this pair"))
                }

                fields(editorHeight: 40)
            }
            .padding(10)
            .background(ReplacerTheme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func fields(editorHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledInput(title: tr("Texto a buscar", "Find")) {
                PromptTextEditor(text: $find, prompt: tr("Cadena exacta que quieres localizar", "Exact text you want to find"))
                    .frame(minHeight: editorHeight)
            }

            LabeledInput(title: tr("Texto de reemplazo", "Replace with")) {
                PromptTextEditor(text: $replace, prompt: tr("Nuevo texto que se escribirá", "New text to write"))
                    .frame(minHeight: editorHeight)
            }
        }
    }
}

private struct RecipesMenu: View {
    @ObservedObject var viewModel: FileReplaceViewModel

    var body: some View {
        Menu {
            Button(tr("Importar pares desde CSV…", "Import Pairs from CSV…")) {
                viewModel.importRulesFromCSV()
            }

            Button(tr("Guardar como receta…", "Save as Recipe…")) {
                viewModel.saveCurrentRulesAsRecipe()
            }
            .disabled(viewModel.activeRules.isEmpty)

            if !viewModel.recipes.isEmpty {
                Divider()

                Section(tr("Recetas guardadas", "Saved recipes")) {
                    ForEach(viewModel.recipes) { recipe in
                        Button("\(recipe.name) (\(recipe.rules.count))") {
                            viewModel.applyRecipe(recipe)
                        }
                    }
                }

                Menu(tr("Eliminar receta", "Delete Recipe")) {
                    ForEach(viewModel.recipes) { recipe in
                        Button(recipe.name, role: .destructive) {
                            viewModel.deleteRecipe(recipe)
                        }
                    }
                }
            }
        } label: {
            Label(tr("Recetas", "Recipes"), systemImage: "list.bullet.rectangle")
                .font(.caption.weight(.semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(tr("Guarda y reutiliza listas de pares, o impórtalas desde un CSV", "Save and reuse lists of pairs, or import them from a CSV file"))
    }
}
