import CoreGraphics
import Foundation
import Testing
@testable import UMLApplication
@testable import UMLDomain

@Suite("CommandHistory & Gaphor Model/Diagram Separation Tests")
struct CommandHistoryTests {
    @Test("Adding, updating, and undoing classifiers preserves model/diagram consistency")
    func addUpdateAndUndoClassifier() {
        let diagram = UMLDiagram(name: "Principal")
        var project = UMLProject(name: "Test", model: UMLModel(), diagrams: [diagram])
        let history = CommandHistoryManager()

        let cls = UMLClassifierFactory.makeClassifier(kind: .class, name: "Cliente")
        history.execute(AddClassifierCommand(classifier: cls, diagramID: diagram.id, position: CGPoint(x: 100, y: 120)), on: &project)

        #expect(project.model.classifiers.count == 1)
        #expect(project.diagrams[0].nodes.count == 1)
        #expect(history.canUndo == true)

        var updated = cls
        updated.name = "ClienteVIP"
        history.execute(UpdateClassifierCommand(oldClassifier: cls, newClassifier: updated), on: &project)
        #expect(project.model.classifier(for: cls.id)?.name == "ClienteVIP")

        #expect(history.undo(on: &project) == true)
        #expect(project.model.classifier(for: cls.id)?.name == "Cliente")

        #expect(history.undo(on: &project) == true)
        #expect(project.model.classifiers.isEmpty)
        #expect(project.diagrams[0].nodes.isEmpty)

        #expect(history.redo(on: &project) == true)
        #expect(project.model.classifiers.count == 1)
        #expect(project.diagrams[0].nodes.count == 1)
    }

    @Test("Removing a node from one diagram keeps semantic classifier in model (Gaphor separation)")
    func removeNodeKeepsSemanticModel() {
        var project = SampleProjectFactory.makeEcommerceSample()
        let history = CommandHistoryManager()
        let firstDiagramID = project.diagrams[0].id
        let secondDiagramID = project.diagrams[1].id

        let order = project.model.classifier(named: "Order")!
        #expect(project.diagrams[0].contains(classifierID: order.id))
        #expect(project.diagrams[1].contains(classifierID: order.id))

        history.execute(RemoveNodeFromDiagramCommand(classifierID: order.id, diagramID: secondDiagramID, classifierName: order.name), on: &project)

        // Still exists in model and first diagram, removed only from second diagram
        #expect(project.model.classifier(for: order.id) != nil)
        #expect(project.diagrams[0].contains(classifierID: order.id))
        #expect(!project.diagrams[1].contains(classifierID: order.id))

        // Undo restores node and its edges in second diagram
        history.undo(on: &project)
        #expect(project.diagrams[1].contains(classifierID: order.id))
        #expect(!project.diagrams[1].edges.isEmpty)
        #expect(project.diagrams[0].id == firstDiagramID)
    }

    @Test("Deleting classifier from model cascades across diagrams and restores completely on undo")
    func deleteClassifierCascadesAndRestoresOnUndo() {
        var project = SampleProjectFactory.makeEcommerceSample()
        let history = CommandHistoryManager()
        let initialClassifiersCount = project.model.classifiers.count
        let initialRelCount = project.model.relationships.count
        let initialSecondDiagramEdges = project.diagrams[1].edges.count

        let order = project.model.classifier(named: "Order")!
        history.execute(DeleteClassifierFromModelCommand(classifierID: order.id, classifierName: order.name), on: &project)

        #expect(project.model.classifiers.count == initialClassifiersCount - 1)
        #expect(project.model.relationships(involving: order.id).isEmpty)
        #expect(!project.diagrams[0].contains(classifierID: order.id))
        #expect(!project.diagrams[1].contains(classifierID: order.id))

        // Undo restores classifier, all relationships, and all nodes/edges in both diagrams
        history.undo(on: &project)
        #expect(project.model.classifiers.count == initialClassifiersCount)
        #expect(project.model.relationships.count == initialRelCount)
        #expect(project.diagrams[0].contains(classifierID: order.id))
        #expect(project.diagrams[1].contains(classifierID: order.id))
        #expect(project.diagrams[1].edges.count == initialSecondDiagramEdges)
    }
}
