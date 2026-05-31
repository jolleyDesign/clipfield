import SwiftUI
import AppKit

/// A thin draggable divider that resizes an adjacent fixed-width panel.
///
/// `side: .leading` means the panel being resized is to the divider's left
/// (e.g. the sidebar — dragging right widens it). `.trailing` means the panel is
/// to the right (e.g. the preview — dragging left widens it).
struct PanelResizer: View {
    @Binding var width: Double
    let range: ClosedRange<Double>
    var side: HorizontalEdge = .leading

    @State private var startWidth: Double?

    var body: some View {
        Color.clear
            .frame(width: 9)
            .frame(maxHeight: .infinity)
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1)
            )
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let start = startWidth ?? width
                    if startWidth == nil { startWidth = width }
                    let translation = Double(value.translation.width)
                    let delta = side == .leading ? translation : -translation
                    width = min(max(start + delta, range.lowerBound), range.upperBound)
                }
                .onEnded { _ in startWidth = nil }
        )
    }
}
