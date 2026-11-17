import Foundation
import Testing
@testable import UMLApplication
@testable import UMLDomain
@testable import UMLInfrastructure

@Suite("JSON Repository Persistence Tests")
struct JSONRepositoryTests {
    @Test("Encodes and decodes full UMLProject round-trip without data loss")
    func roundTripSerialization() throws {
        let sample = SampleProjectFactory.makeEcommerceSample()
        let repo = JSONProjectRepository()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_project_\(UUID().uuidString).umlproj")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try repo.save(sample, to: tempURL)
        let loaded = try repo.load(from: tempURL)

        #expect(loaded.id == sample.id)
        #expect(loaded.name == sample.name)
        #expect(loaded.model.classifiers.count == sample.model.classifiers.count)
        #expect(loaded.model.relationships.count == sample.model.relationships.count)
        #expect(loaded.diagrams.count == sample.diagrams.count)
        #expect(loaded.diagrams[0].nodes.count == sample.diagrams[0].nodes.count)
        #expect(loaded.diagrams[0].edges.count == sample.diagrams[0].edges.count)
    }
}
