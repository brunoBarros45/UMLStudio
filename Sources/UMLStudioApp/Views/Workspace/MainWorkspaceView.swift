import SwiftUI

/// Root 3-pane macOS workspace combining Model Explorer, Interactive Canvas, and Property Inspector.
public struct MainWorkspaceView: View {
    @Bindable public var workspaceVM: WorkspaceViewModel
    @Bindable public var interactionVM: CanvasInteractionViewModel

    public init(workspaceVM: WorkspaceViewModel, interactionVM: CanvasInteractionViewModel) {
        self.workspaceVM = workspaceVM
        self.interactionVM = interactionVM
    }

    public var body: some View {
        NavigationSplitView {
            ModelExplorerSidebar(workspaceVM: workspaceVM, interactionVM: interactionVM)
        } detail: {
            HSplitView {
                DiagramCanvasView(workspaceVM: workspaceVM, interactionVM: interactionVM)
                    .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)

                PropertyInspectorView(workspaceVM: workspaceVM)
                    .frame(minWidth: 290, idealWidth: 320, maxWidth: 380, maxHeight: .infinity)
            }
        }
        .navigationTitle(workspaceVM.project.name)
        .navigationSubtitle(workspaceVM.activeDiagram?.name ?? "")
        .toolbar {
            WorkspaceToolbar(workspaceVM: workspaceVM, interactionVM: interactionVM)
        }
        .sheet(isPresented: $interactionVM.isShowingMermaidSheet) {
            MermaidStudioSheet(workspaceVM: workspaceVM)
        }
        .alert(
            "Aviso",
            isPresented: Binding(
                get: { workspaceVM.alertMessage != nil },
                set: { if !$0 { workspaceVM.alertMessage = nil } }
            )
        ) {
            Button("Aceptar", role: .cancel) {
                workspaceVM.alertMessage = nil
            }
        } message: {
            Text(workspaceVM.alertMessage ?? "")
        }
    }
}
