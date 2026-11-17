import SwiftUI
import UMLApplication
import UMLDomain

/// Native macOS toolbar content for tool selection, undo/redo, layout, Mermaid, and export.
public struct WorkspaceToolbar: ToolbarContent {
    @Bindable public var workspaceVM: WorkspaceViewModel
    @Bindable public var interactionVM: CanvasInteractionViewModel

    public init(workspaceVM: WorkspaceViewModel, interactionVM: CanvasInteractionViewModel) {
        self.workspaceVM = workspaceVM
        self.interactionVM = interactionVM
    }

    public var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                workspaceVM.openProjectWithPanel()
            } label: {
                Label("Abrir", systemImage: "folder")
            }
            .help("Abrir proyecto (.umlproj)")

            Button {
                workspaceVM.saveProject()
            } label: {
                Label("Guardar", systemImage: "square.and.arrow.down")
            }
            .help("Guardar proyecto (.umlproj)")
        }

        ToolbarItemGroup(placement: .principal) {
            Button {
                workspaceVM.undo()
            } label: {
                Label("Deshacer", systemImage: "arrow.uturn.backward")
            }
            .disabled(!workspaceVM.canUndo)
            .help(workspaceVM.undoActionName.map { "Deshacer: \($0)" } ?? "Deshacer")

            Button {
                workspaceVM.redo()
            } label: {
                Label("Rehacer", systemImage: "arrow.uturn.forward")
            }
            .disabled(!workspaceVM.canRedo)
            .help(workspaceVM.redoActionName.map { "Rehacer: \($0)" } ?? "Rehacer")

            Divider()

            Button {
                interactionVM.activeTool = .select
            } label: {
                Label("Seleccionar", systemImage: "cursorarrow")
            }
            .tint(interactionVM.activeTool == .select ? .accentColor : .primary)

            Button {
                interactionVM.activeTool = .pan
            } label: {
                Label("Mover Lienzo", systemImage: "hand.raised")
            }
            .tint(interactionVM.activeTool == .pan ? .accentColor : .primary)

            Menu {
                ForEach(UMLClassifierKind.allCases, id: \.self) { kind in
                    Button {
                        let count = workspaceVM.activeDiagram?.nodes.count ?? 0
                        let offset = CGFloat((count % 6) * 36)
                        workspaceVM.addClassifier(
                            kind: kind,
                            at: CGPoint(x: 160 + offset, y: 120 + offset)
                        )
                        interactionVM.activeTool = .select
                    } label: {
                        Label(kind.rawValue, systemImage: kind.systemImageName)
                    }
                }
            } label: {
                Label("Agregar Entidad", systemImage: "plus.rectangle")
            }

            Menu {
                ForEach(UMLRelationshipKind.allCases, id: \.self) { relKind in
                    Button {
                        interactionVM.activeTool = .connect(relKind)
                    } label: {
                        Label(relKind.displayName, systemImage: relKind.systemImageName)
                    }
                }
            } label: {
                Label("Conectar Relación", systemImage: "arrow.triangle.branch")
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button("Auto-Layout Jerárquico (UML)") {
                    workspaceVM.applyLayout(strategy: HierarchicalLayoutStrategy())
                }
                Button("Auto-Layout en Grilla") {
                    workspaceVM.applyLayout(strategy: GridLayoutStrategy())
                }
                Divider()
                Button(workspaceVM.activeDiagram?.showGrid == true ? "Ocultar Grilla" : "Mostrar Grilla") {
                    workspaceVM.toggleGrid()
                }
                Button(workspaceVM.activeDiagram?.snapToGrid == true ? "Desactivar Snap 16pt" : "Activar Snap 16pt") {
                    workspaceVM.toggleSnapToGrid()
                }
            } label: {
                Label("Organizar", systemImage: "square.grid.2x2")
            }

            Button {
                interactionVM.isShowingMermaidSheet = true
            } label: {
                Label("Mermaid", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .help("Importar o Exportar código Mermaid (classDiagram)")

            Menu {
                Button("Exportar como PNG (Retina 2x)...") {
                    workspaceVM.exportPNGWithPanel()
                }
                Button("Exportar como PDF Vectorial...") {
                    workspaceVM.exportPDFWithPanel()
                }
                Divider()
                Button("Guardar Proyecto (.umlproj)...") {
                    workspaceVM.saveProjectAsWithPanel()
                }
            } label: {
                Label("Exportar", systemImage: "square.and.arrow.up")
            }
        }
    }
}
