import Foundation
import Testing
@testable import UMLApplication
@testable import UMLDomain
@testable import UMLInfrastructure

@Suite("Mermaid classDiagram Codec Tests")
struct MermaidCodecTests {
    @Test("Round-trip export and import preserves classifiers, members, and all 7 UML relationship types")
    func roundTripExportAndImport() throws {
        let sample = SampleProjectFactory.makeEcommerceSample()
        let codec = MermaidClassDiagramCodec()

        let mermaidText = codec.export(project: sample, diagramID: nil)
        #expect(mermaidText.contains("classDiagram"))
        #expect(mermaidText.contains("<<interface>>"))
        #expect(mermaidText.contains("<<enumeration>>"))
        #expect(mermaidText.contains("*--"))
        #expect(mermaidText.contains("o--"))
        #expect(mermaidText.contains("--|>"))
        #expect(mermaidText.contains("..|>"))
        #expect(mermaidText.contains("..>"))

        var targetProject = UMLProject(name: "Imported", model: UMLModel(), diagrams: [UMLDiagram(name: "D1")])
        try codec.importCode(mermaidText, into: &targetProject, diagramID: targetProject.diagrams[0].id)

        #expect(targetProject.model.classifiers.count == sample.model.classifiers.count)
        #expect(targetProject.model.relationships.count == sample.model.relationships.count)

        let importedAuth = try #require(targetProject.model.classifier(named: "Authenticatable"))
        #expect(importedAuth.kind == .interface)
        #expect(importedAuth.operations.count == 2)

        let importedStatus = try #require(targetProject.model.classifier(named: "OrderStatus"))
        #expect(importedStatus.kind == .enumeration)
        #expect(importedStatus.enumLiterals.contains("DELIVERED"))

        // Verify composition multiplicity survived
        let compRel = targetProject.model.relationships.first { $0.kind == .composition }
        #expect(compRel?.source.multiplicity == "1")
        #expect(compRel?.target.multiplicity == "1..*")
    }

    @Test("Imports reversed Mermaid arrows (`<|--`, `<|..`, `--*`, `--o`, `<--`) accurately")
    func importsReversedMermaidArrows() throws {
        let mermaid = """
        classDiagram
            class Animal {
                +name: String
                +speak() Void
            }
            class Dog
            class Runnable {
                <<interface>>
                +run() Void
            }
            class Pack
            Animal <|-- Dog
            Runnable <|.. Dog
            Dog --* Pack : belongsTo
        """
        let codec = MermaidClassDiagramCodec()
        var project = UMLProject(name: "RevTest", model: UMLModel(), diagrams: [UMLDiagram(name: "Main")])
        try codec.importCode(mermaid, into: &project, diagramID: nil)

        let dog = try #require(project.model.classifier(named: "Dog"))
        let animal = try #require(project.model.classifier(named: "Animal"))
        let runnable = try #require(project.model.classifier(named: "Runnable"))
        let pack = try #require(project.model.classifier(named: "Pack"))

        let gen = project.model.relationships.first { $0.kind == .generalization }
        #expect(gen?.source.classifierID == dog.id)
        #expect(gen?.target.classifierID == animal.id)

        let real = project.model.relationships.first { $0.kind == .realization }
        #expect(real?.source.classifierID == dog.id)
        #expect(real?.target.classifierID == runnable.id)

        let comp = project.model.relationships.first { $0.kind == .composition }
        #expect(comp?.source.classifierID == pack.id)
        #expect(comp?.target.classifierID == dog.id)
        #expect(comp?.name == "belongsTo")
    }
}
