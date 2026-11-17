import Foundation
import UMLDomain

/// JSON repository adapter implementing `ProjectRepositoryPort` for `.umlproj` files.
public struct JSONProjectRepository: ProjectRepositoryPort {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    public func save(_ project: UMLProject, to url: URL) throws {
        let data = try encode(project)
        try data.write(to: url, options: .atomic)
    }

    public func load(from url: URL) throws -> UMLProject {
        let data = try Data(contentsOf: url)
        return try decode(from: data)
    }

    public func encode(_ project: UMLProject) throws -> Data {
        try encoder.encode(project)
    }

    public func decode(from data: Data) throws -> UMLProject {
        try decoder.decode(UMLProject.self, from: data)
    }
}
