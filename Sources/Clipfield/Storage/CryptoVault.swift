import Foundation
import CryptoKit
import Security
import AppKit

/// Owns the app's at-rest encryption: a single 256-bit AES-GCM key kept in the
/// Keychain, plus transparent encode/decode helpers used by the model accessors.
///
/// Encryption is opt-in (see `isEnabled`). Payload fields are stored either as
/// plaintext blobs (encryption off) or AES-GCM sealed blobs (on); each model row
/// records which mode it is in via its own `encrypted` flag, so mixed states are
/// safe while a toggle re-encrypts existing history.
///
/// All access happens on the main thread in this app (SwiftData's `mainContext`
/// and the menu-bar UI), so no actor isolation is needed; `NSCache` is itself
/// thread-safe. Crypto failures are non-destructive: decode returns `nil` rather
/// than clobbering ciphertext, and getters never write.
final class CryptoVault {
    static let shared = CryptoVault()

    /// UserDefaults flag that drives whether *new* writes are encrypted.
    static let enabledDefaultsKey = "encryptionEnabled"

    private let keychainService = Bundle.main.bundleIdentifier ?? "com.arivo.clipfield"
    private let keychainAccount = "clipboard.encryptionKey"

    /// Cached after first Keychain fetch to avoid a round-trip per decode.
    private var loadedKey: SymmetricKey?

    /// Bounded, auto-evicting cache of decoded thumbnails so list redraws don't
    /// re-decrypt + re-decode PNGs on every pass. Keyed by `ClipItem.id`.
    private let thumbnailCache = NSCache<NSUUID, NSImage>()

    private init() {}

    // MARK: Global state

    /// Whether newly written payloads should be encrypted.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
    }

    /// The mode an item created right now should be stored in.
    var shouldEncryptNewItems: Bool { isEnabled }

    // MARK: Key management

    /// Loads the existing key or creates and stores one. Returns false if the key
    /// could not be provisioned (e.g. Keychain denied) — callers should refuse to
    /// enable encryption in that case rather than risk unreadable data.
    @discardableResult
    func ensureKey() -> Bool {
        if loadedKey != nil { return true }
        if let existing = readKey() {
            loadedKey = existing
            return true
        }
        let key = SymmetricKey(size: .bits256)
        guard storeKey(key) else { return false }
        loadedKey = key
        return true
    }

    private var key: SymmetricKey? {
        if let loadedKey { return loadedKey }
        return ensureKey() ? loadedKey : nil
    }

    // MARK: Encode / decode

    func encodeString(_ string: String?, encrypted: Bool) -> Data? {
        guard let string else { return nil }
        return encode(Data(string.utf8), encrypted: encrypted)
    }

    func decodeString(_ blob: Data?, encrypted: Bool) -> String? {
        guard let data = decode(blob, encrypted: encrypted) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    func encodeData(_ data: Data?, encrypted: Bool) -> Data? {
        guard let data else { return nil }
        return encode(data, encrypted: encrypted)
    }

    func decodeData(_ blob: Data?, encrypted: Bool) -> Data? {
        decode(blob, encrypted: encrypted)
    }

    private func encode(_ data: Data, encrypted: Bool) -> Data? {
        guard encrypted else { return data }
        guard let key else { return nil }
        return try? AES.GCM.seal(data, using: key).combined
    }

    private func decode(_ blob: Data?, encrypted: Bool) -> Data? {
        guard let blob else { return nil }
        guard encrypted else { return blob }
        guard let key,
              let box = try? AES.GCM.SealedBox(combined: blob) else { return nil }
        return try? AES.GCM.open(box, using: key)
    }

    // MARK: Thumbnail cache

    func cachedThumbnail(id: UUID, cipher: Data?, encrypted: Bool) -> NSImage? {
        let cacheKey = id as NSUUID
        if let cached = thumbnailCache.object(forKey: cacheKey) { return cached }
        guard let data = decodeData(cipher, encrypted: encrypted),
              let image = NSImage(data: data) else { return nil }
        thumbnailCache.setObject(image, forKey: cacheKey)
        return image
    }

    func invalidateThumbnail(id: UUID) {
        thumbnailCache.removeObject(forKey: id as NSUUID)
    }

    // MARK: Keychain

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            // Data-protection keychain: item access is keyed to the app identity
            // rather than a per-binary ACL, which avoids prompts on ad-hoc rebuilds.
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    private func readKey() -> SymmetricKey? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private func storeKey(_ key: SymmetricKey) -> Bool {
        let keyData = key.withUnsafeBytes { Data($0) }
        var attributes = baseQuery()
        attributes[kSecValueData as String] = keyData
        // Device-local, available after first unlock so background capture works
        // while the screen is locked; never migrates to another Mac.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecSuccess { return true }
        if status == errSecDuplicateItem {
            // Already present (race / leftover) — fetch it instead of failing.
            return readKey() != nil
        }
        return false
    }
}
