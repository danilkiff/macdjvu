import MacDjVuCore
import SwiftUI
import UniformTypeIdentifiers

private let djvuTypes = [
    UTType(filenameExtension: "djvu"),
    UTType(filenameExtension: "djv"),
].compactMap { $0 }

/// Vertical spacing between pages in the scroll view (points).
private let pageGap: CGFloat = 12

/// Minimum window dimensions (points).
private let minWindowWidth: CGFloat = 600
private let minWindowHeight: CGFloat = 400

struct ContentView: View {
    @Environment(ViewerState.self) private var state
    @State private var showFileImporter = false

    var body: some View {
        Group {
            if state.fileURL != nil {
                documentView
            } else {
                placeholderView
            }
        }
        .navigationTitle(state.fileURL?.deletingPathExtension().lastPathComponent ?? "MacDjVu")
        .navigationSubtitle(state.fileURL != nil ? "Page \(state.currentPage) of \(state.pageCount)" : "")
        .toolbar { toolbarContent }
        .toolbarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: djvuTypes
        ) { result in
            if case .success(let url) = result {
                Task { await state.openFile(url) }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: \.isDjVu) else { return false }
            Task { await state.openFile(url) }
            return true
        }
        .alert("Error", isPresented: .init(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK") { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: minWindowWidth, minHeight: minWindowHeight)
        .background(Color(white: 0.2))
        .focusable()
        .onKeyPress(.rightArrow) { state.nextPage(); return .handled }
        .onKeyPress(.leftArrow) { state.prevPage(); return .handled }
        .onKeyPress(.pageDown) { state.nextPage(); return .handled }
        .onKeyPress(.pageUp) { state.prevPage(); return .handled }
        .onKeyPress(.home) { state.goToPage(1); return .handled }
        .onKeyPress(.end) { state.goToPage(state.pageCount); return .handled }
        .onKeyPress("+") { state.zoomIn(); return .handled }
        .onKeyPress("=") { state.zoomIn(); return .handled }
        .onKeyPress("-") { state.zoomOut(); return .handled }
    }

    // MARK: - Document view

    private var documentView: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: pageGap) {
                ForEach(1...state.pageCount, id: \.self) { page in
                    PageView(pageNumber: page)
                }
            }
            .padding(.vertical, pageGap)
        }
        .scrollPosition(id: Binding<Int?>(
            get: { state.currentPage },
            set: { if let p = $0 { state.goToPage(p) } }
        ), anchor: .top)
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Drop a .djvu file here or press \u{2318}O")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            Button {
                state.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(state.fileURL == nil || state.scalePercent <= ViewerState.zoomMin)
            .help("Zoom out")

            Button {
                state.setZoom(100)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .disabled(state.fileURL == nil)
            .help("Actual size")

            Button {
                state.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(state.fileURL == nil || state.scalePercent >= ViewerState.zoomMax)
            .help("Zoom in")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showFileImporter = true
            } label: {
                Image(systemName: "folder")
            }
            .keyboardShortcut("o")
            .help("Open file")
        }
    }

}
