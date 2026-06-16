import Foundation

/// A single teleprompter script.
public struct Script: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String

    public init(id: UUID = UUID(), title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

/// The full persisted library: every script plus which one is selected.
public struct ScriptLibraryState: Codable, Equatable, Sendable {
    public var scripts: [Script]
    public var selectedID: UUID?

    public init(scripts: [Script] = [], selectedID: UUID? = nil) {
        self.scripts = scripts
        self.selectedID = selectedID
    }
}
