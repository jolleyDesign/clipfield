import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct OverlayView: View {
    @ObservedObject var presentation: OverlayPresentation
    var onPaste: (OverlayPasteRequest) -> Void
    var onClose: () -> Void

    @Environment(\.modelContext) private var context

    @Query(sort: \ClipItem.createdAt, order: .reverse)
    private var items: [ClipItem]
    @Query(sort: \Folder.sortIndex, order: .forward)
    private var folders: [Folder]
    @Query(sort: \Snippet.sortIndex, order: .forward)
    private var snippets: [Snippet]

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var activeTag: SmartTag?
    @State private var scope: Scope = .all
    @State private var hoveredID: PersistentIdentifier?
    @State private var showNewFolderPrompt = false
    @State private var newFolderName = ""
    @FocusState private var folderFieldFocused: Bool

    @State private var stackIDs: [PersistentIdentifier] = []
    @State private var showEditor = false
    @State private var editingText = ""
    @State private var editingIsCode = false
    @FocusState private var editorFocused: Bool
    @State private var showShortcuts = false

    // Snippets
    @State private var showSnippetEditor = false
    @State private var editingSnippet: Snippet?
    @State private var snippetTitle = ""
    @State private var snippetContent = ""
    @FocusState private var snippetTitleFocused: Bool
    @State private var showFillPrompt = false
    @State private var fillSnippet: Snippet?
    @State private var fillValues: [String: String] = [:]
    @FocusState private var focusedFillField: String?

    /// `true` while any inline prompt is up, so list shortcuts stand down.
    private var promptShowing: Bool {
        showNewFolderPrompt || showEditor || showShortcuts || showSnippetEditor || showFillPrompt
    }

    private func dismissTopPrompt() {
        if showShortcuts { showShortcuts = false }
        else if showFillPrompt { showFillPrompt = false }
        else if showSnippetEditor { showSnippetEditor = false }
        else if showEditor { showEditor = false }
        else if showNewFolderPrompt { cancelNewFolder() }
        else { onClose() }
    }

    @AppStorage(AppearanceKeys.accent) private var accentRaw = AccentTheme.system.rawValue
    @AppStorage(AppearanceKeys.colorScheme) private var colorSchemeRaw = AppColorScheme.system.rawValue
    @AppStorage(AppearanceKeys.showPreview) private var showPreview = true
    @AppStorage(AppearanceKeys.sidebarCollapsed) private var sidebarCollapsed = false
    @AppStorage(AppearanceKeys.sidebarWidth) private var sidebarWidth = 150.0
    @AppStorage(AppearanceKeys.previewWidth) private var previewWidth = 232.0

    @Namespace private var chipNS
    @Namespace private var sidebarNS

    private let chipTags: [SmartTag] = [.link, .image, .email, .phone, .color, .code, .file]

    init(presentation: OverlayPresentation,
         onPaste: @escaping (OverlayPasteRequest) -> Void,
         onClose: @escaping () -> Void) {
        self.presentation = presentation
        self.onPaste = onPaste
        self.onClose = onClose
    }

    enum Scope: Hashable {
        case all, pinned, snippets, folder(PersistentIdentifier)
    }

    private var accent: Color { (AccentTheme(rawValue: accentRaw) ?? .system).color }
    private var preferredScheme: ColorScheme? { (AppColorScheme(rawValue: colorSchemeRaw) ?? .system).swiftUI }

    private var inSnippets: Bool { scope == .snippets }

    // MARK: Filtering

    private var scopedItems: [ClipItem] {
        switch scope {
        case .all: return items
        case .pinned: return items.filter(\.pinned)
        case .snippets: return []
        case .folder(let id): return items.filter { $0.folder?.persistentModelID == id }
        }
    }

    private var results: [ClipItem] {
        SearchEngine.filter(scopedItems, query: query, activeTag: activeTag)
            .sorted { $0.pinned && !$1.pinned }
    }

    private var snippetResults: [Snippet] {
        guard query.isEmpty == false else { return snippets }
        let q = query.lowercased()
        return snippets.filter { $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q) }
    }

    /// Number of rows in the currently displayed list.
    private var activeCount: Int { inSnippets ? snippetResults.count : results.count }

    private var clampedIndex: Int {
        guard activeCount > 0 else { return 0 }
        return min(max(0, selectedIndex), activeCount - 1)
    }

    private var selectedItem: ClipItem? {
        guard !inSnippets, results.indices.contains(clampedIndex) else { return nil }
        return results[clampedIndex]
    }

    private var selectedSnippet: Snippet? {
        guard inSnippets, snippetResults.indices.contains(clampedIndex) else { return nil }
        return snippetResults[clampedIndex]
    }

    // MARK: Body

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if !sidebarCollapsed {
                    sidebar
                        .frame(width: sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    PanelResizer(width: $sidebarWidth, range: 120...320, side: .leading)
                }

                VStack(spacing: 0) {
                    searchBar
                    if inSnippets { snippetToolbar } else { chipBar }
                    Divider()
                    resultsList
                    Divider()
                    footer
                }
                .frame(minWidth: 360, maxWidth: .infinity)

                if showPreview {
                    PanelResizer(width: $previewWidth, range: 200...440, side: .trailing)
                    Group {
                        if inSnippets {
                            SnippetPreviewPane(snippet: selectedSnippet)
                        } else {
                            ClipPreviewPane(item: selectedItem)
                        }
                    }
                    .frame(width: previewWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            if showNewFolderPrompt { newFolderPrompt }
            if showEditor { editorPrompt }
            if showSnippetEditor { snippetEditorPrompt }
            if showFillPrompt { fillPrompt }
            if showShortcuts { shortcutsSheet }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelCornerRadius)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .scaleEffect(presentation.visible ? 1 : 0.9)
        .opacity(presentation.visible ? 1 : 0)
        .background(shortcutButtons)
        .tint(accent)
        .preferredColorScheme(preferredScheme)
    }

    // MARK: New folder prompt (inline — a system alert would dismiss the panel)

    private var newFolderPrompt: some View {
        ZStack {
            Color.black.opacity(0.28)
                .onTapGesture { cancelNewFolder() }

            VStack(spacing: 16) {
                Label("New Folder", systemImage: "folder.badge.plus")
                    .font(.headline)
                TextField("Folder name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 230)
                    .focused($folderFieldFocused)
                    .onSubmit { createFolder() }
                HStack {
                    Button("Cancel", role: .cancel) { cancelNewFolder() }
                        .keyboardShortcut(.cancelAction)
                    Button("Create") { createFolder() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .onAppear {
            DispatchQueue.main.async { folderFieldFocused = true }
        }
    }

    // MARK: Edit-before-paste prompt

    private var editorPrompt: some View {
        ZStack {
            Color.black.opacity(0.28)
                .onTapGesture { showEditor = false }

            VStack(alignment: .leading, spacing: 14) {
                Label("Edit & Paste", systemImage: "pencil")
                    .font(.headline)
                TextEditor(text: $editingText)
                    .font(editingIsCode ? .system(size: 12.5, design: .monospaced) : .system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 180)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.1)))
                    .focused($editorFocused)
                HStack {
                    Text("⌘↩ to paste")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel", role: .cancel) { showEditor = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Paste") { commitEdited() }
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(width: 440)
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .onAppear {
            DispatchQueue.main.async { editorFocused = true }
        }
    }

    // MARK: Snippet editor prompt

    private var snippetEditorPrompt: some View {
        ZStack {
            Color.black.opacity(0.28)
                .onTapGesture { showSnippetEditor = false }

            VStack(alignment: .leading, spacing: 12) {
                Label(editingSnippet == nil ? "New Snippet" : "Edit Snippet", systemImage: "text.badge.star")
                    .font(.headline)
                TextField("Title", text: $snippetTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($snippetTitleFocused)
                TextEditor(text: $snippetContent)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 170)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.1)))
                Text("Tip: use {{name}} for fill-in fields.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { showSnippetEditor = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Save") { saveSnippet() }
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(width: 460)
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .onAppear {
            DispatchQueue.main.async { snippetTitleFocused = true }
        }
    }

    // MARK: Placeholder fill prompt

    private var fillPrompt: some View {
        ZStack {
            Color.black.opacity(0.28)
                .onTapGesture { showFillPrompt = false }

            VStack(alignment: .leading, spacing: 12) {
                Label("Fill in “\(fillSnippet?.title ?? "")”", systemImage: "square.and.pencil")
                    .font(.headline)
                ForEach(fillSnippet?.placeholders ?? [], id: \.self) { name in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.caption).foregroundStyle(.secondary)
                        TextField(name, text: Binding(
                            get: { fillValues[name] ?? "" },
                            set: { fillValues[name] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedFillField, equals: name)
                        .onSubmit { advanceFillFocus(from: name) }
                    }
                }
                HStack {
                    Text("⌘↩ to paste")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel", role: .cancel) { showFillPrompt = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Paste") { commitFill() }
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(width: 380)
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .onAppear {
            DispatchQueue.main.async { focusedFillField = fillSnippet?.placeholders.first }
        }
    }

    private func advanceFillFocus(from name: String) {
        let fields = fillSnippet?.placeholders ?? []
        guard let idx = fields.firstIndex(of: name) else { return }
        if idx + 1 < fields.count {
            focusedFillField = fields[idx + 1]
        } else {
            commitFill() // submitting the last field pastes
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Clipfield")
                .font(.system(size: 15, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 6)

            sidebarRow(title: "All", systemImage: "tray.full.fill", scopeValue: .all)
            sidebarRow(title: "Pinned", systemImage: "pin.fill", scopeValue: .pinned)
            sidebarRow(title: "Snippets", systemImage: "text.badge.star", scopeValue: .snippets,
                       count: snippets.count)

            if !folders.isEmpty {
                Text("FOLDERS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 2)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(folders) { folder in
                        sidebarRow(
                            title: folder.name,
                            systemImage: "folder.fill",
                            scopeValue: .folder(folder.persistentModelID),
                            count: folder.items.count
                        )
                        .contextMenu {
                            Button("Delete Folder", role: .destructive) { deleteFolder(folder) }
                        }
                    }
                }
            }

            Spacer()

            Button {
                presentNewFolder()
            } label: {
                Label("New Folder", systemImage: "plus.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private func sidebarRow(title: String, systemImage: String, scopeValue: Scope, count: Int? = nil) -> some View {
        let active = scope == scopeValue
        return Button {
            withAnimation(Theme.selectionSpring) { scope = scopeValue }
            selectedIndex = 0
        } label: {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title).lineLimit(1)
                Spacer(minLength: 4)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(active ? Color.white.opacity(0.85) : .secondary)
                }
            }
            .font(.system(size: 13, weight: active ? .semibold : .regular))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(active ? Color.white : Color.primary)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.accentGradient)
                        .matchedGeometryEffect(id: "sidebarSel", in: sidebarNS)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    // MARK: Search + chips

    private var searchBar: some View {
        HStack(spacing: 9) {
            SearchField(
                text: $query,
                isActive: !promptShowing,
                onMoveUp: { moveSelection(-1) },
                onMoveDown: { moveSelection(1) },
                onSubmit: { commitSelection() },
                onSubmitPlain: { commitSelection(plain: true) },
                onToggleStack: { if let selectedItem { toggleStack(selectedItem) } },
                onPasteStack: { pasteStack() },
                onDeleteWhenEmpty: { deleteSelected() },
                onCancel: { dismissTopPrompt() }
            )
            .frame(height: 26)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .animation(.easeOut(duration: 0.12), value: query.isEmpty)
    }

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(chipTags, id: \.self) { tag in
                    chip(tag)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    private func chip(_ tag: SmartTag) -> some View {
        let active = activeTag == tag
        return Button {
            withAnimation(Theme.selectionSpring) {
                activeTag = active ? nil : tag
            }
            selectedIndex = 0
        } label: {
            Label(tag.label, systemImage: tag.systemImage)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    if active {
                        Capsule().fill(Theme.accentGradient)
                            .matchedGeometryEffect(id: "chipSel", in: chipNS)
                    } else {
                        Capsule().fill(Color.primary.opacity(0.07))
                    }
                }
                .foregroundStyle(active ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Snippet toolbar

    private var snippetToolbar: some View {
        HStack {
            Button {
                presentSnippetEditor(nil)
            } label: {
                Label("New Snippet", systemImage: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accentGradient))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: Results

    @ViewBuilder
    private var resultsList: some View {
        if inSnippets {
            snippetList
        } else if results.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            ClipRowView(
                                item: item,
                                isSelected: index == clampedIndex,
                                isHovered: hoveredID == item.persistentModelID,
                                stackOrder: stackOrder(of: item)
                            )
                            .id(item.id)
                            .onDrag { dragProvider(for: item) }
                            .simultaneousGesture(TapGesture().onEnded { onPaste(.item(item, plain: false)) })
                            .onHover { hovering in
                                hoveredID = hovering ? item.persistentModelID : (hoveredID == item.persistentModelID ? nil : hoveredID)
                            }
                            .contextMenu { rowMenu(for: item) }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: clampedIndex) { _, newValue in
                    guard results.indices.contains(newValue) else { return }
                    withAnimation(Theme.selectionSpring) {
                        proxy.scrollTo(results[newValue].id, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var snippetList: some View {
        if snippetResults.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "text.badge.star")
                    .font(.system(size: 38))
                    .foregroundStyle(.tertiary)
                Text(query.isEmpty ? "No snippets yet. Create one with “New Snippet”." : "No matches.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(snippetResults.enumerated()), id: \.element.id) { index, snippet in
                            SnippetRowView(snippet: snippet, isSelected: index == clampedIndex)
                                .id(snippet.id)
                                .onDrag { NSItemProvider(object: snippet.content as NSString) }
                                .simultaneousGesture(TapGesture().onEnded { useSnippet(snippet) })
                                .contextMenu {
                                    Button("Insert", systemImage: "arrow.down.doc") { useSnippet(snippet) }
                                    Button("Edit…", systemImage: "pencil") { presentSnippetEditor(snippet) }
                                    Divider()
                                    Button("Delete", systemImage: "trash", role: .destructive) { deleteSnippet(snippet) }
                                }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: clampedIndex) { _, newValue in
                    guard snippetResults.indices.contains(newValue) else { return }
                    withAnimation(Theme.selectionSpring) {
                        proxy.scrollTo(snippetResults[newValue].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: query.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 38))
                .foregroundStyle(.tertiary)
                .symbolEffect(.bounce, value: query)
            Text(query.isEmpty ? "Nothing here yet." : "No matches.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(Theme.selectionSpring) { sidebarCollapsed.toggle() }
            } label: {
                Image(systemName: sidebarCollapsed ? "sidebar.left" : "sidebar.left")
                    .foregroundStyle(sidebarCollapsed ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.borderless)
            .help(sidebarCollapsed ? "Show sidebar" : "Hide sidebar")

            Button {
                withAnimation(Theme.selectionSpring) { showPreview.toggle() }
            } label: {
                Image(systemName: "sidebar.right")
                    .foregroundStyle(showPreview ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(showPreview ? "Hide preview" : "Show preview")

            Spacer()
            if !stackIDs.isEmpty {
                Button {
                    pasteStack()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("Paste All (\(stackIDs.count))")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.9)))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("Paste all stacked items (⇧↩)")
                Button { withAnimation(Theme.selectionSpring) { stackIDs.removeAll() } } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear stack")
            }
            Text("\(activeCount)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showShortcuts.toggle() }
            } label: {
                Image(systemName: "keyboard")
            }
            .buttonStyle(.borderless)
            .help("Keyboard shortcuts")
            Menu {
                Button("Clear Unpinned") { HistoryStore(context: context).clearUnpinned() }
                Button("Clear All History", role: .destructive) { HistoryStore(context: context).clearAll() }
            } label: {
                Image(systemName: "trash")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Clear history")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    // MARK: Shortcuts cheat-sheet

    private var shortcutsSheet: some View {
        ZStack {
            Color.black.opacity(0.28)
                .onTapGesture { showShortcuts = false }

            VStack(alignment: .leading, spacing: 9) {
                Label("Keyboard Shortcuts", systemImage: "keyboard")
                    .font(.headline)
                Divider()
                shortcutRow("↩", "Paste")
                shortcutRow("⌥↩", "Paste as plain text")
                shortcutRow("⌘1–9", "Quick-paste the Nth item")
                shortcutRow("⇥", "Add / remove from paste stack")
                shortcutRow("⇧↩", "Paste the whole stack")
                shortcutRow("⌘E", "Edit before pasting")
                shortcutRow("⌘P", "Pin / unpin")
                shortcutRow("⌘⌫", "Delete")
                shortcutRow("⌘[ / ⌘]", "Previous / next section")
                shortcutRow("⎋", "Close")
                HStack {
                    Spacer()
                    Button("Done") { showShortcuts = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 4)
            }
            .frame(width: 340)
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
    }

    private func shortcutRow(_ key: String, _ label: String) -> some View {
        HStack(spacing: 10) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(minWidth: 42)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.1)))
            Text(label)
                .font(.system(size: 12.5))
            Spacer()
        }
    }

    // MARK: Context menu

    @ViewBuilder
    private func rowMenu(for item: ClipItem) -> some View {
        Button("Paste", systemImage: "doc.on.clipboard") { onPaste(.item(item, plain: false)) }
        if item.text != nil {
            Button("Paste as Plain Text", systemImage: "textformat") { onPaste(.item(item, plain: true)) }
        }
        Button("Copy", systemImage: "doc.on.doc") { onPaste(.copyItem(item)) }
        if item.text != nil {
            Button("Edit & Paste…", systemImage: "pencil") { beginEditing(item) }
        }

        Divider()
        if stackIDs.contains(item.persistentModelID) {
            Button("Remove from Paste Stack", systemImage: "minus.square") { toggleStack(item) }
        } else {
            Button("Add to Paste Stack", systemImage: "plus.square.on.square") { toggleStack(item) }
        }

        if let url = linkURL(for: item) {
            Button("Open Link", systemImage: "safari") { NSWorkspace.shared.open(url); onClose() }
        }
        if let url = fileURL(for: item) {
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([url]); onClose()
            }
        }

        if let text = item.text, !text.isEmpty {
            Menu("Transform & Paste") {
                ForEach(TextTransform.allCases) { transform in
                    Button(transform.label) {
                        if let result = transform.apply(to: text) { onPaste(.text(result)) }
                    }
                }
            }
        }

        Divider()

        Button(item.pinned ? "Unpin" : "Pin", systemImage: "pin") { togglePin(item) }
        Menu("Move to Folder") {
            if item.folder != nil {
                Button("Remove from Folder") { move(item, to: nil) }
                Divider()
            }
            ForEach(folders) { folder in
                Button(folder.name) { move(item, to: folder) }
            }
            if !folders.isEmpty { Divider() }
            Button("New Folder…") { presentNewFolder() }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { delete(item) }
    }

    private func linkURL(for item: ClipItem) -> URL? {
        guard item.kind == .link, let text = item.text,
              let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil else { return nil }
        return url
    }

    private func fileURL(for item: ClipItem) -> URL? {
        guard item.kind == .file, let str = item.fileURLString else { return nil }
        return URL(string: str)
    }

    private var shortcutButtons: some View {
        ZStack {
            Button("") { if !promptShowing, let selectedItem { togglePin(selectedItem) } }
                .keyboardShortcut("p", modifiers: .command)
            // ⌘⌫ (delete item) is handled by the search field so it can also clear
            // the query text — see SearchField.onDeleteWhenEmpty.
            // ⌥⌘V — paste the selection as plain text.
            Button("") { if !promptShowing { commitSelection(plain: true) } }
                .keyboardShortcut("v", modifiers: [.command, .option])
            // ⌘E — edit the selection (clip before paste, or the snippet).
            Button("") {
                guard !promptShowing else { return }
                if let selectedSnippet { presentSnippetEditor(selectedSnippet) }
                else if let selectedItem { beginEditing(selectedItem) }
            }
            .keyboardShortcut("e", modifiers: .command)
            // ⌘[ / ⌘] — cycle through sidebar sections.
            Button("") { if !promptShowing { cycleScope(-1) } }
                .keyboardShortcut("[", modifiers: .command)
            Button("") { if !promptShowing { cycleScope(1) } }
                .keyboardShortcut("]", modifiers: .command)
            // ⌘1–9 — quick-paste / insert the Nth result.
            ForEach(1...9, id: \.self) { n in
                Button("") {
                    guard !promptShowing else { return }
                    if inSnippets {
                        if snippetResults.indices.contains(n - 1) { useSnippet(snippetResults[n - 1]) }
                    } else if results.indices.contains(n - 1) {
                        onPaste(.item(results[n - 1], plain: false))
                    }
                }
                .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
            }
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    // MARK: Actions

    private func moveSelection(_ delta: Int) {
        guard activeCount > 0 else { return }
        withAnimation(Theme.selectionSpring) {
            selectedIndex = min(max(0, clampedIndex + delta), activeCount - 1)
        }
    }

    private func commitSelection(plain: Bool = false) {
        if inSnippets {
            if let selectedSnippet { useSnippet(selectedSnippet) }
        } else if let selectedItem {
            onPaste(.item(selectedItem, plain: plain))
        }
    }

    private func deleteSelected() {
        if let selectedSnippet { deleteSnippet(selectedSnippet) }
        else if let selectedItem { delete(selectedItem) }
    }

    // MARK: Drag out

    /// Provides the right representation(s) when a row is dragged into another app.
    private func dragProvider(for item: ClipItem) -> NSItemProvider {
        // Files: hand over a real file reference.
        if item.kind == .file, let str = item.fileURLString,
           let url = URL(string: str), let provider = NSItemProvider(contentsOf: url) {
            return provider
        }

        let provider = NSItemProvider()

        if item.kind == .image, let data = item.imageData {
            provider.suggestedName = "Image.png"
            // Expose the image as a *file* (promise), not just raw data — web/
            // Electron drop targets (Figma, browsers) only accept dropped files.
            // Consumers wanting raw data can still read it from this file.
            provider.registerFileRepresentation(
                forTypeIdentifier: UTType.png.identifier,
                fileOptions: [],
                visibility: .all
            ) { completion in
                do {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("clip-\(UUID().uuidString).png")
                    try data.write(to: url)
                    completion(url, false, nil)
                } catch {
                    completion(nil, false, error)
                }
                return nil
            }
            return provider
        }

        if let rtf = item.rtfData {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.rtf.identifier, visibility: .all) { done in
                done(rtf, nil); return nil
            }
        }
        if item.kind == .link, let text = item.text,
           let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme != nil {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all) { done in
                done(url.dataRepresentation, nil); return nil
            }
        }
        if let text = item.text {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all) { done in
                done(Data(text.utf8), nil); return nil
            }
        }
        return provider
    }

    private func setScope(_ newScope: Scope) {
        withAnimation(Theme.selectionSpring) { scope = newScope }
        selectedIndex = 0
    }

    /// All selectable sidebar scopes in display order.
    private var orderedScopes: [Scope] {
        [.all, .pinned, .snippets] + folders.map { .folder($0.persistentModelID) }
    }

    private func cycleScope(_ delta: Int) {
        let scopes = orderedScopes
        let current = scopes.firstIndex(of: scope) ?? 0
        let next = (current + delta + scopes.count) % scopes.count
        setScope(scopes[next])
    }

    // MARK: Paste stack

    private func stackOrder(of item: ClipItem) -> Int? {
        guard let idx = stackIDs.firstIndex(of: item.persistentModelID) else { return nil }
        return idx + 1
    }

    private func toggleStack(_ item: ClipItem) {
        withAnimation(Theme.selectionSpring) {
            if let idx = stackIDs.firstIndex(of: item.persistentModelID) {
                stackIDs.remove(at: idx)
            } else {
                stackIDs.append(item.persistentModelID)
            }
        }
    }

    private func pasteStack() {
        guard !stackIDs.isEmpty else { commitSelection(); return }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.persistentModelID, $0) })
        let combined = stackIDs
            .compactMap { byID[$0] }
            .map { $0.text ?? $0.previewText }
            .joined(separator: "\n")
        onPaste(.text(combined))
    }

    // MARK: Edit before paste

    private func beginEditing(_ item: ClipItem) {
        guard let text = item.text else { return }
        editingText = text
        editingIsCode = (item.kind == .code)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showEditor = true }
    }

    private func commitEdited() {
        let text = editingText
        showEditor = false
        onPaste(.text(text))
    }

    private func togglePin(_ item: ClipItem) {
        withAnimation(Theme.selectionSpring) { item.pinned.toggle() }
        try? context.save()
    }

    private func delete(_ item: ClipItem) {
        let wasSelected = (item.id == selectedItem?.id)
        withAnimation(.easeOut(duration: 0.18)) { context.delete(item) }
        try? context.save()
        if wasSelected { selectedIndex = max(0, selectedIndex - 1) }
    }

    private func move(_ item: ClipItem, to folder: Folder?) {
        item.folder = folder
        try? context.save()
    }

    private func presentNewFolder() {
        newFolderName = ""
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showNewFolderPrompt = true
        }
    }

    private func cancelNewFolder() {
        folderFieldFocused = false
        newFolderName = ""
        withAnimation(.easeOut(duration: 0.15)) { showNewFolderPrompt = false }
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancelNewFolder(); return }
        let folder = Folder(name: name, sortIndex: folders.count)
        context.insert(folder)
        try? context.save()
        cancelNewFolder()
    }

    private func deleteFolder(_ folder: Folder) {
        if scope == .folder(folder.persistentModelID) { scope = .all }
        context.delete(folder)
        try? context.save()
    }

    // MARK: Snippets

    /// Inserts a snippet: fills placeholders first if it has any, else pastes now.
    private func useSnippet(_ snippet: Snippet) {
        snippet.usageCount += 1
        snippet.lastUsedAt = .now
        try? context.save()

        if snippet.placeholders.isEmpty {
            onPaste(.text(snippet.content))
        } else {
            fillSnippet = snippet
            fillValues = Dictionary(uniqueKeysWithValues: snippet.placeholders.map { ($0, "") })
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showFillPrompt = true }
        }
    }

    private func commitFill() {
        guard let snippet = fillSnippet else { return }
        let text = snippet.filled(with: fillValues)
        showFillPrompt = false
        onPaste(.text(text))
    }

    private func presentSnippetEditor(_ snippet: Snippet?) {
        editingSnippet = snippet
        snippetTitle = snippet?.title ?? ""
        snippetContent = snippet?.content ?? ""
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showSnippetEditor = true }
    }

    private func saveSnippet() {
        let title = snippetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = snippetContent
        guard !title.isEmpty || !content.isEmpty else { showSnippetEditor = false; return }

        if let snippet = editingSnippet {
            snippet.title = title.isEmpty ? "Untitled" : title
            snippet.content = content
        } else {
            let snippet = Snippet(
                title: title.isEmpty ? "Untitled" : title,
                content: content,
                sortIndex: snippets.count
            )
            context.insert(snippet)
        }
        try? context.save()
        withAnimation(.easeOut(duration: 0.15)) { showSnippetEditor = false }
    }

    private func deleteSnippet(_ snippet: Snippet) {
        let wasSelected = (snippet.id == selectedSnippet?.id)
        withAnimation(.easeOut(duration: 0.18)) { context.delete(snippet) }
        try? context.save()
        if wasSelected { selectedIndex = max(0, selectedIndex - 1) }
    }
}
