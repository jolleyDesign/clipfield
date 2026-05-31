import Foundation
import SwiftData

extension Notification.Name {
    /// Posted after the clip history changes (insert / clear), so views that
    /// don't use @Query (e.g. the menu bar) can refresh.
    static let clipHistoryChanged = Notification.Name("clipHistoryChanged")
}

/// Inserts captured clips into the store with de-duplication and retention.
@MainActor
struct HistoryStore {
    let context: ModelContext

    static let retentionLimitKey = "retentionLimit"
    static let defaultRetentionLimit = 500

    /// Items kept (0 means unlimited). Pinned items never count toward the cap.
    static var retentionLimit: Int {
        let stored = UserDefaults.standard.integer(forKey: retentionLimitKey)
        return stored == 0 ? defaultRetentionLimit : stored
    }

    /// Inserts a capture. If identical content already exists it is moved to the
    /// top instead of duplicated. Returns the resulting item.
    @discardableResult
    func insert(_ capture: CapturedClip) -> ClipItem? {
        let hash = capture.contentHash
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.contentHash == hash })

        if let existing = try? context.fetch(descriptor).first {
            existing.createdAt = .now
            if existing.sourceAppName == nil { existing.sourceAppName = capture.sourceAppName }
            try? context.save()
            notifyChanged()
            return existing
        }

        let item = ClipItem(
            kind: capture.kind,
            contentHash: capture.contentHash,
            text: capture.text,
            rtfData: capture.rtfData,
            htmlString: capture.htmlString,
            imageData: capture.imageData,
            thumbnailData: capture.thumbnailData,
            rawFlavors: capture.rawFlavors,
            fileURLString: capture.fileURLString,
            tags: capture.tags,
            sourceAppName: capture.sourceAppName,
            sourceAppBundleID: capture.sourceAppBundleID
        )
        context.insert(item)
        try? context.save()
        prune()
        notifyChanged()
        return item
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .clipHistoryChanged, object: nil)
    }

    /// Deletes the oldest unpinned items beyond the retention limit.
    func prune() {
        let limit = Self.retentionLimit
        guard limit > 0 else { return }

        var descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate { $0.pinned == false },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = .max
        guard let items = try? context.fetch(descriptor), items.count > limit else { return }

        for item in items[limit...] {
            context.delete(item)
        }
        try? context.save()
    }

    /// Removes every item that isn't pinned.
    func clearUnpinned() {
        try? context.delete(model: ClipItem.self, where: #Predicate { $0.pinned == false })
        try? context.save()
        notifyChanged()
    }

    /// Removes all history, including pinned items.
    func clearAll() {
        try? context.delete(model: ClipItem.self)
        try? context.save()
        notifyChanged()
    }
}
