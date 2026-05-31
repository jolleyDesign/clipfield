import Foundation
import SwiftData

/// Owns the app's SwiftData stack. The store lives in Application Support and
/// holds clipboard history locally (never leaves the device).
@MainActor
final class DataController {
    static let shared = DataController()

    let container: ModelContainer

    /// Bumped whenever the persisted schema changes incompatibly. On a mismatch the
    /// old store is wiped (clipboard history is ephemeral and retention-capped), so
    /// we never hit SwiftData's `fatalError` migration path.
    private static let schemaGeneration = 2
    private static let schemaGenerationKey = "storeSchemaGeneration"

    private init() {
        let schema = Schema([ClipItem.self, Folder.self, Snippet.self])

        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clipfield", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        let storeURL = appSupport.appendingPathComponent("history.store")
        Self.wipeStoreIfSchemaChanged(at: storeURL)

        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var mainContext: ModelContext { container.mainContext }

    /// Removes the store and its sidecar/external files when the stored schema
    /// generation predates the current one, then records the new generation.
    private static func wipeStoreIfSchemaChanged(at storeURL: URL) {
        let defaults = UserDefaults.standard
        let stored = defaults.integer(forKey: schemaGenerationKey)
        guard stored < schemaGeneration else { return }

        let fm = FileManager.default
        // The SQLite store is three files; external `.externalStorage` blobs live in
        // a sibling support directory. Remove all of them for a clean V2 store.
        let dir = storeURL.deletingLastPathComponent()
        let base = storeURL.lastPathComponent
        if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for url in contents where url.lastPathComponent.hasPrefix(base) {
                try? fm.removeItem(at: url)
            }
        }

        // The fresh store is empty; let it be reseeded with the sample clips.
        SampleData.forgetSeedMarker()
        defaults.set(schemaGeneration, forKey: schemaGenerationKey)
    }
}
