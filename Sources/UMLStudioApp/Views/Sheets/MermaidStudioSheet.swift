import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Modal sheet for bidirectional Mermaid `classDiagram` import and export.
public struct MermaidStudioSheet: View {
    @Bindable public var workspaceVM: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Tab = .export
    @State private var exportScope: ExportScope = .activeDiagram
    @State private var importCodeText: String = Self.sampleMermaidTemplate
    @State private var importIntoNewDiagram: Bool = true
    @State private var feedbackMessage: String?
    @State private var isErrorFeedback: Bool = false

    private enum Tab: String, CaseIterable {
        case export = "Exportar a Mermaid"
        case `import` = "Importar desde Mermaid"
    }

    private enum ExportScope: String, CaseIterable {
        case activeDiagram = "Diagrama Activo"
        case fullModel = "Modelo Completo"
    }

    public init(workspaceVM: WorkspaceViewModel) {
        self.workspaceVM = workspaceVM
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(Color.accentColor)
                Text("Mermaid Studio (`classDiagram`)")
                    .font(.title3.bold())
                Spacer()
                Button("Cerrar") { dismiss() }
            }

            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            if selectedTab == .export {
                exportView
            } else {
                importView
            }

            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(.caption)
                    .foregroundStyle(isErrorFeedback ? .red : .green)
            }
        }
        .padding(18)
        .frame(width: 680, height: 520)
    }

    @ViewBuilder
    private var exportView: some View {
        let code = exportScope == .activeDiagram
            ? workspaceVM.exportActiveDiagramToMermaid()
            : workspaceVM.exportFullModelToMermaid()

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Alcance:", selection: $exportScope) {
                    ForEach(ExportScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)

                Spacer()

                Button("Copiar Código") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    feedbackMessage = "Código Mermaid copiado al portapapeles."
                    isErrorFeedback = false
                }

                Button("Guardar .mmd...") {
                    saveMermaidFile(code)
                }
                .buttonStyle(.borderedProminent)
            }

            TextEditor(text: .constant(code))
                .font(.system(.callout, design: .monospaced))
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
        }
    }

    @ViewBuilder
    private var importView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Crear un nuevo diagrama con el resultado", isOn: $importIntoNewDiagram)
                Spacer()
                Button("Cargar Ejemplo") {
                    importCodeText = Self.sampleMermaidTemplate
                    feedbackMessage = nil
                }
                Button("Importar Diagrama") {
                    runImport()
                }
                .buttonStyle(.borderedProminent)
            }

            TextEditor(text: $importCodeText)
                .font(.system(.callout, design: .monospaced))
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
        }
    }

    private func runImport() {
        do {
            try workspaceVM.importMermaid(importCodeText, intoNewDiagram: importIntoNewDiagram)
            feedbackMessage = "Diagrama Mermaid importado con auto-layout jerárquico."
            isErrorFeedback = false
            dismiss()
        } catch {
            feedbackMessage = error.localizedDescription
            isErrorFeedback = true
        }
    }

    private func saveMermaidFile(_ code: String) {
        let panel = NSSavePanel()
        panel.title = "Guardar archivo Mermaid (.mmd)"
        panel.nameFieldStringValue = "diagrama.mmd"
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try code.write(to: url, atomically: true, encoding: .utf8)
            feedbackMessage = "Guardado en \(url.lastPathComponent)"
            isErrorFeedback = false
        } catch {
            feedbackMessage = error.localizedDescription
            isErrorFeedback = true
        }
    }

    private static let sampleMermaidTemplate = """
    classDiagram
        class Repository {
            <<interface>>
            +findById(id: UUID) Entity?
            +save(entity: Entity) Void
        }
        class Account {
            -id: UUID
            -balance: Decimal = 0.0
            +deposit(amount: Decimal) Void
            +withdraw(amount: Decimal) Bool
        }
        class Transaction {
            +timestamp: Date
            +amount: Decimal
        }
        Account ..|> Repository : implements
        Account "1" *-- "0..*" Transaction : records
    """
}
