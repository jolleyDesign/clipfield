import Foundation
import SwiftData

/// Seeds a few illustrative clips and a snippet on first launch so the picker
/// isn't empty — a lightweight guided tour of the rich types and snippets.
enum SampleData {
    private static let seededKey = "didSeedSamples"

    /// Clears the "already seeded" marker so the next launch reseeds. Called when
    /// the store is wiped for a schema change, otherwise the fresh store stays empty.
    static func forgetSeedMarker() {
        UserDefaults.standard.removeObject(forKey: seededKey)
    }

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)

        // Only seed a genuinely empty store, so we never clutter real history.
        let clipCount = (try? context.fetchCount(FetchDescriptor<ClipItem>())) ?? 0
        let snippetCount = (try? context.fetchCount(FetchDescriptor<Snippet>())) ?? 0
        guard clipCount == 0, snippetCount == 0 else { return }

        let samples = [
            "👋 Welcome to Clipfield! Press ⇧⌘V anywhere to open this picker, then type to search or use ↑ ↓ to browse. Press ↩ to paste.",
            "https://www.google.com",
            "hello@example.com",
            "#5E5CE6",
            "func greet(name: String) {\n    print(\"Hello, \\(name)!\")\n}"
        ]

        for (index, text) in samples.enumerated() {
            let capture = CapturedClip(kind: .text, contentHash: "sample-\(index)", text: text)
            let analysis = SmartTagger.analyze(capture)
            let item = ClipItem(
                kind: analysis.kind,
                contentHash: capture.contentHash,
                text: text,
                tags: analysis.tags,
                sourceAppName: "Clipfield"
            )
            // Stagger timestamps so the welcome note stays on top.
            item.createdAt = Date().addingTimeInterval(Double(-index))
            if index == 0 { item.pinned = true }
            context.insert(item)
        }

        let snippet = Snippet(
            title: "Email sign-off",
            content: "Best regards,\n{{name}}\n{{title}}"
        )
        context.insert(snippet)

        try? context.save()
    }
}
