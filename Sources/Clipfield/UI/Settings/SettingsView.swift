import SwiftUI
import SwiftData
import AppKit

struct SettingsView: View {
    @AppStorage(AppearanceKeys.colorScheme) private var colorSchemeRaw = AppColorScheme.system.rawValue
    @AppStorage(AppearanceKeys.accent) private var accentRaw = AccentTheme.system.rawValue

    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            AppearanceSettings().tabItem { Label("Appearance", systemImage: "paintbrush") }
            HistorySettings().tabItem { Label("History", systemImage: "clock") }
            PrivacySettings().tabItem { Label("Privacy", systemImage: "hand.raised") }
            SecuritySettings().tabItem { Label("Security", systemImage: "lock.shield") }
        }
        .frame(width: 520, height: 430)
        .tint((AccentTheme(rawValue: accentRaw) ?? .system).color)
        .preferredColorScheme((AppColorScheme(rawValue: colorSchemeRaw) ?? .system).swiftUI)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @State private var hotkeyDisplay = HotkeyStore.display
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Global Shortcut") {
                LabeledContent("Open clipboard picker") {
                    HotkeyRecorder(display: $hotkeyDisplay) { keyCode, modifiers, glyphs in
                        HotkeyStore.set(keyCode: keyCode, modifiers: modifiers, display: glyphs)
                        HotKeyManager.shared.register(keyCode: keyCode, modifiers: modifiers)
                    }
                    .frame(width: 150, height: 26)
                }
                Text("Press this combination anywhere to open the picker over the current app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLogin.setEnabled(enabled)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @AppStorage(AppearanceKeys.accent) private var accentRaw = AccentTheme.system.rawValue
    @AppStorage(AppearanceKeys.colorScheme) private var colorSchemeRaw = AppColorScheme.system.rawValue
    @AppStorage(AppearanceKeys.overlaySize) private var overlaySizeRaw = OverlaySize.standard.rawValue
    @AppStorage(AppearanceKeys.showPreview) private var showPreview = true

    var body: some View {
        Form {
            Section("Theme") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accent color")
                    accentPicker
                }
                .padding(.vertical, 2)

                Picker("Appearance", selection: $colorSchemeRaw) {
                    ForEach(AppColorScheme.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section("Overlay") {
                Picker("Window size", selection: $overlaySizeRaw) {
                    ForEach(OverlaySize.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .onChange(of: overlaySizeRaw) { _, raw in
                    // Picking a preset resets any custom drag-resized dimensions.
                    let card = (OverlaySize(rawValue: raw) ?? .standard).card
                    UserDefaults.standard.set(Double(card.width), forKey: AppearanceKeys.contentWidth)
                    UserDefaults.standard.set(Double(card.height), forKey: AppearanceKeys.contentHeight)
                }
                Text("You can also drag the window edges to resize, and drag the dividers to resize the sidebar and preview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Show preview pane", isOn: $showPreview)
            }
        }
        .formStyle(.grouped)
    }

    private var accentPicker: some View {
        HStack(spacing: 10) {
            ForEach(AccentTheme.allCases) { theme in
                let selected = accentRaw == theme.rawValue
                Button {
                    accentRaw = theme.rawValue
                } label: {
                    ZStack {
                        Circle()
                            .fill(theme == .system ? AnyShapeStyle(.gray.gradient) : AnyShapeStyle(theme.color.gradient))
                            .frame(width: 22, height: 22)
                        if theme == .system {
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                        }
                        if selected {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.85), lineWidth: 2)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .help(theme.label)
            }
        }
    }
}

// MARK: - History

private struct HistorySettings: View {
    @AppStorage(HistoryStore.retentionLimitKey) private var retention = HistoryStore.defaultRetentionLimit

    var body: some View {
        Form {
            Section("Retention") {
                Stepper(value: $retention, in: 50...5000, step: 50) {
                    LabeledContent("Items to keep", value: "\(retention)")
                }
                Text("Older unpinned items are removed once the limit is reached. Pinned items are always kept.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Manage") {
                Button("Clear Unpinned Items") {
                    HistoryStore(context: DataController.shared.mainContext).clearUnpinned()
                }
                Button("Clear All History", role: .destructive) {
                    HistoryStore(context: DataController.shared.mainContext).clearAll()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Privacy

private struct PrivacySettings: View {
    @State private var excluded = ExclusionManager.excludedBundleIDs

    var body: some View {
        Form {
            Section("Excluded Apps") {
                if excluded.isEmpty {
                    Text("No apps excluded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(excluded, id: \.self) { bundleID in
                        HStack {
                            Image(systemName: "app.dashed").foregroundStyle(.secondary)
                            Text(displayName(for: bundleID))
                            Spacer()
                            Button {
                                ExclusionManager.remove(bundleID: bundleID)
                                excluded = ExclusionManager.excludedBundleIDs
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Add App…", systemImage: "plus") { addExcludedApp() }
            }

            Section {
                Label("Content marked private by password managers is always ignored.",
                      systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func displayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }

    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        ExclusionManager.add(bundleID: id)
        excluded = ExclusionManager.excludedBundleIDs
    }
}

// MARK: - Security

private struct SecuritySettings: View {
    @State private var enabled = UserDefaults.standard.bool(forKey: CryptoVault.enabledDefaultsKey)
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Encryption") {
                Toggle("Encrypt clipboard data at rest", isOn: $enabled)
                    .disabled(working)
                    .onChange(of: enabled) { _, newValue in apply(newValue) }

                if working {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(enabled ? "Encrypting existing history…" : "Decrypting existing history…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Clip and snippet contents are sealed with AES-GCM using a 256-bit key stored "
                     + "in your Mac's Keychain. The key never leaves this device. Turning this on or "
                     + "off re-encrypts your existing history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Label("Timestamps, the source app, type/tags, and a non-reversible content hash "
                      + "(used for de-duplication, search, and sorting) are kept unencrypted.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .alert("Couldn’t enable encryption", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    /// Persists the flag, provisions the key, then re-encodes all existing items
    /// and snippets to match. Reverts the toggle if the key can't be provisioned.
    private func apply(_ newValue: Bool) {
        guard !working else { return }

        // Need the key in both directions: to encrypt when enabling, and to decrypt
        // existing ciphertext when disabling.
        guard CryptoVault.shared.ensureKey() else {
            errorMessage = "The encryption key could not be created or read from the Keychain."
            enabled = false
            return
        }

        UserDefaults.standard.set(newValue, forKey: CryptoVault.enabledDefaultsKey)
        working = true

        Task { @MainActor in
            await reencryptAll(to: newValue)
            working = false
            NotificationCenter.default.post(name: .clipHistoryChanged, object: nil)
        }
    }

    private func reencryptAll(to value: Bool) async {
        let context = DataController.shared.mainContext

        if let items = try? context.fetch(FetchDescriptor<ClipItem>()) {
            for (index, item) in items.enumerated() {
                item.applyEncryption(value)
                // Save in batches and yield so the UI stays responsive.
                if index % 50 == 49 {
                    try? context.save()
                    await Task.yield()
                }
            }
        }
        if let snippets = try? context.fetch(FetchDescriptor<Snippet>()) {
            for snippet in snippets { snippet.applyEncryption(value) }
        }
        try? context.save()
    }
}
