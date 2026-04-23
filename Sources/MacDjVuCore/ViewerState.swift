import AppKit
import Foundation
import Observation

/// Fallback page dimensions (pixels) when djvused query fails.
/// A4 at 300 DPI.
private let fallbackPageSize = (width: 2480, height: 3508)

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

    public var fileURL: URL?
    @ObservationIgnored private var scopedResource: ScopedResource?
    // Pages currently being rendered; prevents duplicate concurrent renders for the same page.
    @ObservationIgnored private var renderingPages: Set<Int> = []
    public var pageCount: Int = 0
    public var currentPage: Int = 1
    public var scalePercent: Int = 100
    /// Cached native page sizes, keyed by 1-based page number.
    public var pageSizes: [Int: (width: Int, height: Int)] = [:]
    public var errorMessage: String?

    // Image cache keyed by 1-based page number
    public var renderedPages: [Int: NSImage] = [:]

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

    public func setZoom(_ percent: Int) {
        let clamped = max(Self.zoomMin, min(Self.zoomMax, percent))
        guard clamped != scalePercent else { return }
        scalePercent = clamped
        renderedPages.removeAll()
    }

    // MARK: - Display geometry

    public var displayWidth: CGFloat {
        max(1, DjVuRenderer.baseWidth * CGFloat(scalePercent) / 100)
    }

    public func displayHeight(page: Int = 1) -> CGFloat {
        let size = pageSizes[page] ?? pageSizes[1] ?? fallbackPageSize
        return DjVuRenderer.scaledPageHeight(
            nativeWidth: size.width,
            nativeHeight: size.height,
            scalePercent: scalePercent
        )
    }

    // MARK: - Rendering

    public func renderPageIfNeeded(_ page: Int) async {
        guard let url = fileURL,
              renderedPages[page] == nil,
              !renderingPages.contains(page) else { return }

        renderingPages.insert(page)
        defer { renderingPages.remove(page) }

        let scale = scalePercent
        do {
            let (data, nativeSize) = try await Task.detached {
                try DjVuRenderer.renderPage(file: url, page: page, scalePercent: scale)
            }.value
            // Only store if zoom hasn't changed while we were rendering
            if scalePercent == scale {
                renderedPages[page] = NSImage(data: data)
                pageSizes[page] = nativeSize
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
