import AppKit
import SwiftData

/// Polls the general pasteboard for changes (NSPasteboard has no change
/// notification) and records new content into the store.
@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private let store: HistoryStore
    private var lastChangeCount: Int
    private var timer: Timer?

    init(context: ModelContext) {
        self.store = HistoryStore(context: context)
        // Start from the current count so we don't re-capture whatever is already
        // on the clipboard at launch — only new copies are recorded.
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start(interval: TimeInterval = 0.4) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer?.tolerance = interval / 4
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard var capture = PasteboardReader.read(pasteboard) else { return }
        guard !ExclusionManager.isExcluded(bundleID: capture.sourceAppBundleID) else { return }

        // Auto-detect semantic categories and refine the primary kind.
        let analysis = SmartTagger.analyze(capture)
        capture.kind = analysis.kind
        capture.tags = analysis.tags

        store.insert(capture)
    }
}
