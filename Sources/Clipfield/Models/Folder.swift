import Foundation
import SwiftData

@Model
final class Folder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    /// Display ordering for the sidebar (lower sorts first).
    var sortIndex: Int

    @Relationship(deleteRule: .nullify, inverse: \ClipItem.folder)
    var items: [ClipItem]

    init(name: String, sortIndex: Int = 0, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.items = []
    }
}
