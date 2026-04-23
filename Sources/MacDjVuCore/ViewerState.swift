import AppKit
import Foundation
import Observation

/// Fallback page dimensions (pixels) when djvused query fails.
/// A4 at 300 DPI.
private let fallbackPageSize = PageSize(width: 2480, height: 3508)

/// Wraps a security-scoped URL and releases access on deinitialization.
/// Extracting the release into its own type avoids nonisolated(unsafe)
/// on ViewerState properties: Swift auto-releases stored properties in
/// deinit without going through actor isolation checks.
private final class ScopedResource: @unchecked Sendable {
    private let url: URL
    init(_ url: URL) { self.url = url }
    deinit { url.stopAccessingSecurityScopedResource() }
}

@Observable
@MainActor
public final class ViewerState {
    /// Zoom step for zoomIn()/zoomOut(), in percentage points.
    public static let zoomStep = 25
    /// Minimum allowed zoom percentage.
    public static let zoomMin = 50
    /// Maximum allowed zoom percentage.
    public static let zoomMax = 600
    /// Maximum rendered pages kept in cache. Pages farthest from currentPage are evicted first.
    package static let cacheCapacity = 10
    /// Approximate decoded image memory limit for the rendered page cache.
    package static let cacheCostLimit = 256 * 1024 * 1024

    public var fileURL: URL?
    @ObservationIgnored private var scopedResource: ScopedResource?
    // In-flight renders: page → scale being rendered. Prevents duplicate renders per (page, scale).
    @ObservationIgnored package var renderingPages: [Int: Int] = [:]
    // Scale at which each page was last rendered; used to detect stale cache entries.
    @ObservationIgnored package var renderedPageScales: [Int: Int] = [:]
    // Approximate decoded image cost in bytes, keyed by 1-based page number.
    @ObservationIgnored package var renderedPageCosts: [Int: Int] = [:]
    public var pageCount: Int = 0
    public var currentPage: Int = 1
    public var scalePercent: Int = 100
    /// Cached native page sizes, keyed by 1-based page number.
    public internal(set) var pageSizes: [Int: PageSize] = [:]
    public var errorMessage: String?

    /// Image cache keyed by 1-based page number. Written only by renderPageIfNeeded; read by the view layer.
    public internal(set) var renderedPages: [Int: NSImage] = [:]

    // MARK: - Search state

    public var isSearchActive: Bool = false
    public var searchQuery: String = ""
    public internal(set) var searchMatches: [SearchMatch] = []
    public var currentMatchIndex: Int? = nil
    /// Cached extracted text per page (1-based key). Populated on demand during search.
    @ObservationIgnored package var pageTextCache: [Int: DjVuPageText] = [:]

    public init() {}

    // MARK: - File

    public func openFile(_ url: URL) async {
        // fileImporter returns security-scoped URLs; child processes
        // (djvused/ddjvu) inherit access only while the scope is active.
        let scoped = url.startAccessingSecurityScopedResource()
        // Wrap immediately so scope is released automatically on any exit path.
        let resource: ScopedResource? = scoped ? ScopedResource(url) : nil

        do {
            let (count, size) = try await Task.detached(priority: .userInitiated) {
                let count = try DjVuRenderer.pageCount(of: url)
                let size = try DjVuRenderer.pageSize(of: url, page: 1)
                return (count, size)
            }.value

            // Atomically switch to the new document once metadata is ready.
            // Assigning scopedResource releases the previous security scope.
            scopedResource = resource
            fileURL = url
            pageCount = count
            currentPage = 1
            pageSizes = [1: size]
            renderedPages.removeAll()
            renderedPageScales.removeAll()
            renderedPageCosts.removeAll()
            renderingPages.removeAll()
            pageTextCache.removeAll()
            searchMatches = []
            currentMatchIndex = nil
            searchQuery = ""
            errorMessage = nil
        } catch {
            // resource goes out of scope here, releasing the new scope if applicable.
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Navigation

    public func goToPage(_ page: Int) {
        guard fileURL != nil, page >= 1, page <= pageCount else { return }
        currentPage = page
    }

    public func nextPage() {
        if currentPage < pageCount { goToPage(currentPage + 1) }
    }

    public func prevPage() {
        if currentPage > 1 { goToPage(currentPage - 1) }
    }

    // MARK: - Zoom

    public func zoomIn() {
        setZoom(scalePercent + Self.zoomStep)
    }

    public func zoomOut() {
        setZoom(scalePercent - Self.zoomStep)
    }

    /// Sets zoom, clamped to [zoomMin, zoomMax].
    /// Cached images at the previous scale remain visible until re-rendered at the new scale.
    public func setZoom(_ percent: Int) {
        let clamped = max(Self.zoomMin, min(Self.zoomMax, percent))
        guard clamped != scalePercent else { return }
        scalePercent = clamped
    }

    // MARK: - Search

    public func toggleSearch() {
        if isSearchActive {
            dismissSearch()
        } else {
            isSearchActive = true
        }
    }

    public func dismissSearch() {
        isSearchActive = false
        searchQuery = ""
        searchMatches = []
        currentMatchIndex = nil
    }

    public func performSearch(_ query: String) async {
        searchQuery = query
        guard !query.isEmpty, fileURL != nil, pageCount > 0 else {
            searchMatches = []
            currentMatchIndex = nil
            return
        }

        var matches: [SearchMatch] = []
        for page in 1...pageCount {
            let pageText = await extractPageText(page: page)
            // Bail out if query changed during async extraction.
            guard searchQuery == query else { return }
            let pageMatches = DjVuRenderer.findMatches(in: pageText, query: query, page: page)
            matches.append(contentsOf: pageMatches)
        }

        guard searchQuery == query else { return }
        searchMatches = matches
        currentMatchIndex = matches.isEmpty ? nil : 0
        if let first = matches.first {
            goToPage(first.page)
        }
    }

    public func nextMatch() {
        guard !searchMatches.isEmpty, let idx = currentMatchIndex else { return }
        let next = (idx + 1) % searchMatches.count
        currentMatchIndex = next
        goToPage(searchMatches[next].page)
    }

    public func previousMatch() {
        guard !searchMatches.isEmpty, let idx = currentMatchIndex else { return }
        let prev = (idx - 1 + searchMatches.count) % searchMatches.count
        currentMatchIndex = prev
        goToPage(searchMatches[prev].page)
    }

    private func extractPageText(page: Int) async -> DjVuPageText {
        if let cached = pageTextCache[page] {
            return cached
        }
        guard let url = fileURL else {
            return DjVuPageText(words: [])
        }
        do {
            let text = try await Task.detached(priority: .userInitiated) {
                try await DjVuRenderer.pageTextCancellable(of: url, page: page)
            }.value
            pageTextCache[page] = text
            return text
        } catch {
            return DjVuPageText(words: [])
        }
    }

    // MARK: - Display geometry

    public var displayWidth: CGFloat {
        max(1, DjVuRenderer.baseWidth * CGFloat(scalePercent) / 100)
    }

    public func displayHeight(page: Int = 1) -> CGFloat {
        let size = pageSizes[page] ?? pageSizes[1] ?? fallbackPageSize
        return DjVuRenderer.scaledPageHeight(size, scalePercent: scalePercent)
    }

    // MARK: - Rendering

    public func renderPageIfNeeded(_ page: Int) async {
        guard let url = fileURL else { return }
        let scale = scalePercent
        // Cache hit: already rendered at current scale.
        guard renderedPageScales[page] != scale else { return }
        // Dedup: already rendering at current scale.
        guard renderingPages[page] != scale else { return }

        renderingPages[page] = scale
        do {
            let renderTask = Task.detached(priority: .userInitiated) {
                try await DjVuRenderer.renderPageCancellable(file: url, page: page, scalePercent: scale)
            }
            let (data, nativeSize) = try await withTaskCancellationHandler {
                try await renderTask.value
            } onCancel: {
                renderTask.cancel()
            }
            try Task.checkCancellation()
            // Discard if scale or file changed while rendering.
            if scalePercent == scale && fileURL == url {
                let image = try Self.decodeRenderedImage(data, page: page)
                renderedPages[page] = image
                renderedPageScales[page] = scale
                renderedPageCosts[page] = Self.estimatedImageCost(image, nativeSize: nativeSize, scalePercent: scale)
                pageSizes[page] = nativeSize
                evictDistantPages()
            }
        } catch is CancellationError {
            // View-scoped render tasks are cancelled during fast scrolling or zooming.
        } catch {
            errorMessage = error.localizedDescription
        }
        // Release lock only if we still own it (a newer scale may have overwritten it).
        if renderingPages[page] == scale {
            renderingPages.removeValue(forKey: page)
        }
    }

    // MARK: - Cache management

    package var renderedCacheCost: Int {
        renderedPageCosts.values.reduce(0, +)
    }

    /// Evict rendered pages farthest from currentPage when cache exceeds capacity.
    package func evictDistantPages() {
        guard shouldEvictRenderedPages else { return }
        let current = currentPage
        let evictionOrder = renderedPages.keys.sorted {
            let lhsDistance = abs($0 - current)
            let rhsDistance = abs($1 - current)
            if lhsDistance == rhsDistance { return $0 > $1 }
            return lhsDistance > rhsDistance
        }

        for page in evictionOrder {
            guard shouldEvictRenderedPages, renderedPages.count > 1 else { break }
            removeRenderedPage(page)
        }
    }

    package static func decodeRenderedImage(_ data: Data, page: Int) throws -> NSImage {
        guard let image = NSImage(data: data) else {
            throw ViewerStateError.invalidRenderedImage(page: page)
        }
        return image
    }

    package static func estimatedImageCost(_ image: NSImage, nativeSize: PageSize, scalePercent: Int) -> Int {
        if let representation = image.representations.max(by: { lhs, rhs in
            lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
        }), representation.pixelsWide > 0, representation.pixelsHigh > 0 {
            return representation.pixelsWide * representation.pixelsHigh * 4
        }

        let targetW = max(1, Int(DjVuRenderer.baseWidth) * scalePercent / 100)
        let targetH = max(1, targetW * nativeSize.height / nativeSize.width)
        return targetW * targetH * 4
    }

    private var shouldEvictRenderedPages: Bool {
        renderedPages.count > Self.cacheCapacity || renderedCacheCost > Self.cacheCostLimit
    }

    private func removeRenderedPage(_ page: Int) {
        renderedPages.removeValue(forKey: page)
        renderedPageScales.removeValue(forKey: page)
        renderedPageCosts.removeValue(forKey: page)
    }
}

public enum ViewerStateError: Error, LocalizedError, Equatable {
    case invalidRenderedImage(page: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidRenderedImage(let page):
            return "Failed to decode rendered image for page \(page)"
        }
    }
}
