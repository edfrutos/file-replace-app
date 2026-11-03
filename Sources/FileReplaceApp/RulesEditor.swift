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
                Text(isSinglePair ? "Buscar y reemplazar" : "\(viewModel.rules.count) pares buscar → reemplazar")
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
                Label("Añadir par", systemImage: "plus.circle")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(ReplacerTheme.blue)
            .help("Busca y reemplaza varios textos a la vez, en una sola pasada")
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
                    Text("Par \(number)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(ReplacerTheme.ink)
                    Spacer()
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Quitar este par")
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
            LabeledInput(title: "Texto a buscar") {
                PromptTextEditor(text: $find, prompt: "Cadena exacta que quieres localizar")
                    .frame(minHeight: editorHeight)
            }

            LabeledInput(title: "Texto de reemplazo") {
                PromptTextEditor(text: $replace, prompt: "Nuevo texto que se escribirá")
                    .frame(minHeight: editorHeight)
            }
        }
    }
}

private struct RecipesMenu: View {
    @ObservedObject var viewModel: FileReplaceViewModel

    var body: some View {
        Menu {
            Button("Importar pares desde CSV…") {
                viewModel.importRulesFromCSV()
            }

            Button("Guardar como receta…") {
                viewModel.saveCurrentRulesAsRecipe()
            }
            .disabled(viewModel.activeRules.isEmpty)

            if !viewModel.recipes.isEmpty {
                Divider()

                Section("Recetas guardadas") {
                    ForEach(viewModel.recipes) { recipe in
                        Button("\(recipe.name) (\(recipe.rules.count))") {
                            viewModel.applyRecipe(recipe)
                        }
                    }
                }

                Menu("Eliminar receta") {
                    ForEach(viewModel.recipes) { recipe in
                        Button(recipe.name, role: .destructive) {
                            viewModel.deleteRecipe(recipe)
                        }
                    }
                }
            }
        } label: {
            Label("Recetas", systemImage: "list.bullet.rectangle")
                .font(.caption.weight(.semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Guarda y reutiliza listas de pares, o impórtalas desde un CSV")
    }
}
