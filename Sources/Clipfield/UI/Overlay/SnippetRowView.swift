import SwiftUI

struct SnippetRowView: View {
    let snippet: Snippet
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AnyShapeStyle(.white.opacity(0.18))
                                     : AnyShapeStyle(Color.accentColor.opacity(0.16)))
                    .frame(width: 38, height: 38)
                Image(systemName: "text.badge.star")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(snippet.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Text(snippet.preview)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : .secondary)
            }

            Spacer(minLength: 6)

            if !snippet.placeholders.isEmpty {
                pill("\(snippet.placeholders.count) field\(snippet.placeholders.count == 1 ? "" : "s")")
            }
            if snippet.usageCount > 0 {
                pill("\(snippet.usageCount)×")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.clear))
                .shadow(color: isSelected ? Color.accentColor.opacity(0.35) : .clear, radius: 6, y: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.rowCornerRadius))
        .animation(Theme.selectionSpring, value: isSelected)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(isSelected ? Color.white.opacity(0.22) : Color.secondary.opacity(0.14)))
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
    }
}

struct SnippetPreviewPane: View {
    let snippet: Snippet?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let snippet {
                HStack(spacing: 8) {
                    Image(systemName: "text.badge.star").foregroundStyle(.tint)
                    Text(snippet.title).font(.headline).lineLimit(1)
                }
                .padding(.bottom, 12)

                ScrollView {
                    Text(snippet.content)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)

                Spacer(minLength: 0)

                if !snippet.placeholders.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FIELDS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                        ForEach(snippet.placeholders, id: \.self) { name in
                            Label(name, systemImage: "curlybraces")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Divider().padding(.vertical, 6)
                }
                HStack {
                    Text("Used").foregroundStyle(.secondary)
                    Spacer()
                    Text("\(snippet.usageCount) time\(snippet.usageCount == 1 ? "" : "s")")
                        .fontWeight(.medium)
                }
                .font(.caption)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "text.badge.star")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    Text("Select a snippet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }
}
