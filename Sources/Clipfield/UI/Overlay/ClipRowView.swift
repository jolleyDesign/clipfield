import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let isSelected: Bool
    let isHovered: Bool
    var stackOrder: Int? = nil

    var body: some View {
        HStack(spacing: 11) {
            badge

            VStack(alignment: .leading, spacing: 3) {
                Text(item.previewText)
                    .lineLimit(2)
                    .font(item.kind == .code ? .system(size: 12.5, design: .monospaced) : .system(size: 13))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                subtitle
            }

            Spacer(minLength: 6)

            if let stackOrder {
                Text("\(stackOrder)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 19, height: 19)
                    .background(Circle().fill(isSelected ? Color.white.opacity(0.3) : Color.accentColor))
                    .help("Position \(stackOrder) in paste stack")
            }

            if item.pasteCount > 0 {
                pill("\(item.pasteCount)×", system: "arrow.down.doc")
            }
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.95) : .orange)
                    .rotationEffect(.degrees(40))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: Theme.rowCornerRadius))
        .animation(Theme.selectionSpring, value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    // MARK: Pieces

    @ViewBuilder
    private var badge: some View {
        if item.kind == .image, let image = item.thumbnail {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.15)))
        } else if item.kind == .color, let swatch = swatchColor {
            RoundedRectangle(cornerRadius: 8)
                .fill(swatch)
                .frame(width: 38, height: 38)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.25)))
                .shadow(color: swatch.opacity(0.5), radius: 4, y: 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AnyShapeStyle(.white.opacity(0.18))
                                     : AnyShapeStyle(item.kind.tint.opacity(0.16)))
                    .frame(width: 38, height: 38)
                Image(systemName: item.kind.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : item.kind.tint)
            }
        }
    }

    private var subtitle: some View {
        let secondary = isSelected ? Color.white.opacity(0.82) : Color.secondary
        return HStack(spacing: 5) {
            if let app = item.sourceAppName {
                Text(app).fontWeight(.medium)
                Text("·")
            }
            Text(item.createdAt, style: .relative)
            ForEach(item.tags.prefix(2), id: \.self) { tag in
                Image(systemName: tag.systemImage).font(.system(size: 9))
            }
        }
        .font(.caption2)
        .foregroundStyle(secondary)
        .lineLimit(1)
    }

    private func pill(_ text: String, system: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: system).font(.system(size: 8))
            Text(text)
        }
        .font(.system(size: 10, weight: .semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(isSelected ? Color.white.opacity(0.22) : Color.secondary.opacity(0.14)))
        .foregroundStyle(isSelected ? Color.white : Color.secondary)
    }

    @ViewBuilder
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
            .fill(
                isSelected ? AnyShapeStyle(Theme.accentGradient)
                           : AnyShapeStyle(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.35) : .clear, radius: 6, y: 2)
    }

    private var swatchColor: Color? {
        guard let text = item.text else { return nil }
        return Color(hexString: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
