import AppKit
import SwiftUI
import UMLApplication
import UMLDomain

@main
struct UMLStudioApp: App {
    @State private var workspaceVM = WorkspaceViewModel()
    @State private var interactionVM = CanvasInteractionViewModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("UMLStudio — Diagramas de Clases UML 2.5") {
            MainWorkspaceView(workspaceVM: workspaceVM, interactionVM: interactionVM)
                .frame(minWidth: 1120, minHeight: 700)
        }
        .defaultSize(width: 1380, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nuevo Proyecto Vacío") {
                    workspaceVM.newBlankProject()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Cargar Proyecto E-Commerce de Ejemplo") {
                    workspaceVM.loadSampleProject()
                }

                Divider()

                Button("Abrir (.umlproj)...") {
                    workspaceVM.openProjectWithPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Guardar (.umlproj)") {
                    workspaceVM.saveProject()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Guardar Como...") {
                    workspaceVM.saveProjectAsWithPanel()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Exportar como PNG...") {
                    workspaceVM.exportPNGWithPanel()
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Exportar como PDF...") {
                    workspaceVM.exportPDFWithPanel()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .undoRedo) {
                Button(workspaceVM.undoActionName.map { "Deshacer \($0)" } ?? "Deshacer") {
                    workspaceVM.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!workspaceVM.canUndo)

                Button(workspaceVM.redoActionName.map { "Rehacer \($0)" } ?? "Rehacer") {
                    workspaceVM.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!workspaceVM.canRedo)
            }

            CommandMenu("Modelado UML") {
                Button("Nueva Clase") {
                    workspaceVM.addClassifier(kind: .class, at: CGPoint(x: 240, y: 200))
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Nueva Clase Abstracta") {
                    workspaceVM.addClassifier(kind: .abstractClass, at: CGPoint(x: 260, y: 220))
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Nueva Interfaz") {
                    workspaceVM.addClassifier(kind: .interface, at: CGPoint(x: 280, y: 240))
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Nueva Enumeración") {
                    workspaceVM.addClassifier(kind: .enumeration, at: CGPoint(x: 300, y: 260))
                }
                .keyboardShortcut("4", modifiers: .command)

                Divider()

                Button("Auto-Layout Jerárquico") {
                    workspaceVM.applyLayout(strategy: HierarchicalLayoutStrategy())
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Mermaid Studio (Importar / Exportar)...") {
                    interactionVM.isShowingMermaidSheet = true
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }
    }
}
