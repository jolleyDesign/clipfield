import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsState
    var onDone: () -> Void

    @AppStorage(AppearanceKeys.accent) private var accentRaw = AccentTheme.system.rawValue
    @AppStorage(AppearanceKeys.colorScheme) private var colorSchemeRaw = AppColorScheme.system.rawValue

    private var trusted: Bool { permissions.accessibilityTrusted }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 46))
                .foregroundStyle(Theme.accentGradient)

            VStack(spacing: 6) {
                Text("Welcome to Clipfield")
                    .font(.title2.bold())
                Text("Press ⇧⌘V anywhere to open the picker, search your history, and paste.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(trusted ? Color.green : Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trusted ? "Accessibility access granted" : "Accessibility access needed")
                            .font(.headline)
                        Text(trusted
                             ? "Selecting an item will paste it straight into the app you’re using."
                             : "Grant access so Clipfield can paste directly into other apps. Until then, items are copied and you can paste with ⌘V yourself.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
            }

            Button {
                if trusted { onDone() } else { permissions.requestAccessibility() }
            } label: {
                Label(trusted ? "Get Started" : "Open Accessibility Settings",
                      systemImage: trusted ? "checkmark" : "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            if !trusted {
                Button("Skip for now") { onDone() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .padding(28)
        .frame(width: 440)
        .tint((AccentTheme(rawValue: accentRaw) ?? .system).color)
        .preferredColorScheme((AppColorScheme(rawValue: colorSchemeRaw) ?? .system).swiftUI)
    }
}
