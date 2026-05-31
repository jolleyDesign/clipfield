import SwiftUI
import AppKit

/// Detail view for the currently highlighted clip, shown on the right of the
/// overlay. Renders images, color swatches, links, and text/code richly.
struct ClipPreviewPane: View {
    let item: ClipItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item {
                content(for: item)
                    .id(item.id)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                Spacer(minLength: 0)
                metadata(for: item)
            } else {
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .animation(.easeOut(duration: 0.18), value: item?.id)
    }

    // MARK: Content

    @ViewBuilder
    private func content(for item: ClipItem) -> some View {
        header(for: item)
            .padding(.bottom, 12)

        switch item.kind {
        case .image:
            if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12)))
            }
        case .color:
            colorPreview(for: item)
        default:
            ScrollView {
                Text(item.text ?? item.previewText)
                    .font(item.kind == .code ? .system(size: 12.5, design: .monospaced) : .system(size: 13.5))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 280)
        }
    }

    private func header(for item: ClipItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.kind.systemImage)
                .foregroundStyle(item.kind.tint)
            Text(item.kind.label)
                .font(.headline)
            Spacer()
            if item.kind == .link, let text = item.text, let url = URL(string: text) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .help("Open link")
            }
        }
    }

    @ViewBuilder
    private func colorPreview(for item: ClipItem) -> some View {
        let text = (item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let color = Color(hexString: text) {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(color)
                    .frame(height: 130)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.2)))
                    .shadow(color: color.opacity(0.5), radius: 10, y: 4)
                Text(text.uppercased())
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Metadata

    private func metadata(for item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(item.tags, id: \.self) { tag in
                        Label(tag.label, systemImage: tag.systemImage)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(item.kind.tint.opacity(0.16)))
                            .foregroundStyle(item.kind.tint)
                    }
                }
            }
            Divider()
            metaRow("Copied", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
            if let app = item.sourceAppName { metaRow("From", value: app) }
            metaRow("Pasted", value: "\(item.pasteCount) time\(item.pasteCount == 1 ? "" : "s")")
            if let folder = item.folder { metaRow("Folder", value: folder.name) }
        }
        .font(.caption)
    }

    private func metaRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).lineLimit(1)
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text("Select an item")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
