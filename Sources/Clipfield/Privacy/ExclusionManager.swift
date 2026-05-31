import Foundation

/// Tracks which source apps the user has chosen to exclude from history.
/// (Concealed-type detection lives in `PasteboardReader`; this handles the
/// explicit per-app opt-out.)
enum ExclusionManager {
    private static let key = "excludedBundleIDs"

    static var excludedBundleIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }

    static func add(bundleID: String) {
        var ids = Set(excludedBundleIDs)
        ids.insert(bundleID)
        excludedBundleIDs = Array(ids).sorted()
    }

    static func remove(bundleID: String) {
        excludedBundleIDs = excludedBundleIDs.filter { $0 != bundleID }
    }
}
