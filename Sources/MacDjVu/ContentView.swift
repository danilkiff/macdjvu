import MacDjVuCore
import SwiftUI
import UniformTypeIdentifiers

private let djvuType = UTType(filenameExtension: "djvu") ?? .data
private let pageGap: CGFloat = 12

struct ContentView: View {
    @Environment(ViewerState.self) private var state
    @State private var showFileImporter = false
    @State private var scrollTarget: Int?

    var body: some View {
        Group {
            if state.fileURL != nil {
                documentView
            } else {
                placeholderView
            }
        }
        .toolbar { toolbarContent }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [djvuType]
        ) { result in
            if case .success(let url) = result {
                state.openFile(url)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .alert("Error", isPresented: .init(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK") { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color(nsColor: .controlBackgroundColor))
        .focusable()
        .onKeyPress(.rightArrow) { state.nextPage(); scrollTo(state.currentPage); return .handled }
        .onKeyPress(.leftArrow) { state.prevPage(); scrollTo(state.currentPage); return .handled }
        .onKeyPress(.pageDown) { state.nextPage(); scrollTo(state.currentPage); return .handled }
        .onKeyPress(.pageUp) { state.prevPage(); scrollTo(state.currentPage); return .handled }
        .onKeyPress(.home) { state.goToPage(1); scrollTo(1); return .handled }
        .onKeyPress(.end) { state.goToPage(state.pageCount); scrollTo(state.pageCount); return .handled }
        .onKeyPress("+") { state.zoomIn(); return .handled }
        .onKeyPress("=") { state.zoomIn(); return .handled }
        .onKeyPress("-") { state.zoomOut(); return .handled }
    }

    // MARK: - Document view

    private var documentView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: pageGap) {
                    ForEach(1...state.pageCount, id: \.self) { page in
                        PageView(pageNumber: page)
                    }
                }
                .padding(.vertical, pageGap)
            }
            .scrollPosition(id: .init(
                get: { scrollTarget },
                set: { newPage in
                    if let p = newPage, p != state.currentPage {
                        state.currentPage = p
                    }
                }
            ), anchor: .top)
            .onChange(of: scrollTarget) { _, target in
                if let target {
                    proxy.scrollTo(target, anchor: .top)
                    scrollTarget = nil
                }
            }
        }
        .background(Color(white: 0.25))
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        Text("Drop a .djvu file here or press \u{2318}O")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button("Open...") { showFileImporter = true }
                .keyboardShortcut("o")

            Spacer()

            Button("< Prev") { state.prevPage(); scrollTo(state.currentPage) }
                .disabled(state.fileURL == nil || state.currentPage <= 1)

            Text("p. \(state.currentPage) / \(state.pageCount)")
                .monospacedDigit()

            Button("Next >") { state.nextPage(); scrollTo(state.currentPage) }
                .disabled(state.fileURL == nil || state.currentPage >= state.pageCount)

            Spacer()

            Text("Zoom:")
            Picker("", selection: Binding(
                get: { state.scalePercent },
                set: { state.setZoom($0) }
            )) {
                ForEach([50, 75, 100, 125, 150, 200, 300], id: \.self) { pct in
                    Text("\(pct)%").tag(pct)
                }
            }
            .frame(width: 80)
        }
    }

    // MARK: - Helpers

    private func scrollTo(_ page: Int) {
        scrollTarget = page
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "djvu"
            else { return }
            Task { @MainActor in state.openFile(url) }
        }
        return true
    }
}
