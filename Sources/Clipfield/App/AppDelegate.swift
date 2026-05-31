import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: ClipboardMonitor?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private let permissions = PermissionsState()
    let overlayController = OverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar / accessory app: no Dock icon, no main window.
        // (LSUIElement in Info.plist already does this for the bundled app;
        //  setting it here covers `swift run` during development too.)
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        // Seed a few sample items on first launch (only when the store is empty).
        SampleData.seedIfNeeded(context: DataController.shared.mainContext)

        // Start watching the clipboard.
        let monitor = ClipboardMonitor(context: DataController.shared.mainContext)
        monitor.start()
        self.monitor = monitor

        // Selecting an item auto-pastes it into the previously focused app.
        overlayController.pasteHandler = { request, previousApp in
            let context = DataController.shared.mainContext
            switch request {
            case .item(let item, let plain):
                Paster.paste(item, into: previousApp, context: context, plain: plain)
            case .text(let string):
                Paster.pasteText(string, into: previousApp)
            case .copyItem(let item):
                ClipboardWriter.write(item)
                if let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                    previousApp.activate()
                }
            }
        }

        // Register the global hotkey to summon the overlay (⌘⇧V).
        HotKeyManager.shared.onTrigger = { [weak self] in
            MainActor.assumeIsolated {
                self?.overlayController.toggle()
            }
        }
        HotKeyManager.shared.register(keyCode: HotkeyStore.keyCode, modifiers: HotkeyStore.modifiers)

        // When the user grants Accessibility from the welcome window, close it and
        // pop the picker so they see it working immediately.
        permissions.onBecameTrusted = { [weak self] in
            guard let self, self.onboardingWindow?.isVisible == true else { return }
            self.onboardingWindow?.close()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.overlayController.show()
            }
        }

        // Show the welcome / permissions window on first run until Accessibility
        // is granted.
        permissions.startPolling()
        if !permissions.accessibilityTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        monitor?.stop()
    }

    // MARK: Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipfield")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Clipfield — click to open the picker (⇧⌘V)"
        }
        statusItem = item
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)

        if isRightClick {
            showStatusMenu()
        } else {
            overlayController.toggle()
        }
    }

    private func showStatusMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open Clipfield Picker", action: #selector(openPicker), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let permissionsItem = NSMenuItem(title: "Permissions & Welcome…", action: #selector(showOnboarding), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit Clipfield", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Temporarily attach the menu so a right-click shows it, then detach so the
        // next left-click triggers the action instead of the menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPicker() {
        overlayController.show()
    }

    @objc private func showOnboarding() {
        permissions.refresh()
        if onboardingWindow == nil {
            let root = OnboardingView(permissions: permissions) { [weak self] in
                self?.onboardingWindow?.close()
            }
            onboardingWindow = makeHostedWindow(
                title: "Welcome to Clipfield",
                size: NSSize(width: 440, height: 440),
                root: root
            )
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettings() {
        // Present settings in an AppKit-hosted window. SwiftUI's Settings-opening
        // action isn't reliably reachable from an accessory app's status item.
        if settingsWindow == nil {
            settingsWindow = makeHostedWindow(
                title: "Clipfield Settings",
                size: NSSize(width: 520, height: 430),
                root: SettingsView()
            )
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Builds a fixed-size window hosting a SwiftUI view. Uses a plain
    /// `NSHostingView` with `sizingOptions = []` so the hosting view never drives
    /// the window's size — letting it do so can throw during the AppKit display
    /// cycle (a constraint-update crash) for flexible-height content.
    private func makeHostedWindow(title: String, size: NSSize, root: some View) -> NSWindow {
        let host = NSHostingView(rootView: AnyView(root.frame(width: size.width, height: size.height)))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.center()
        return window
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
