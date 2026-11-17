import Foundation
import UMLDomain

/// Command pattern contract for all reversible mutations on a `UMLProject`.
public protocol ProjectCommand: Sendable {
    var commandName: String { get }
    mutating func execute(on project: inout UMLProject)
    mutating func undo(on project: inout UMLProject)
}

/// Manages undo/redo command stacks without storing monolithic project snapshots.
public final class CommandHistoryManager {
    private var undoStack: [any ProjectCommand] = []
    private var redoStack: [any ProjectCommand] = []
    private let maxHistoryCount: Int

    public init(maxHistoryCount: Int = 100) {
        self.maxHistoryCount = maxHistoryCount
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoActionName: String? { undoStack.last?.commandName }
    public var redoActionName: String? { redoStack.last?.commandName }

    public func execute(_ command: any ProjectCommand, on project: inout UMLProject) {
        var mutableCommand = command
        mutableCommand.execute(on: &project)
        project.updatedAt = Date()

        undoStack.append(mutableCommand)
        if undoStack.count > maxHistoryCount {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    @discardableResult
    public func undo(on project: inout UMLProject) -> Bool {
        guard var command = undoStack.popLast() else { return false }
        command.undo(on: &project)
        project.updatedAt = Date()
        redoStack.append(command)
        return true
    }

    @discardableResult
    public func redo(on project: inout UMLProject) -> Bool {
        guard var command = redoStack.popLast() else { return false }
        command.execute(on: &project)
        project.updatedAt = Date()
        undoStack.append(command)
        return true
    }

    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
